# GPIO UVC – Reusable UVM Verification Component cho GPIO

> Repo này xây dựng một **GPIO UVC độc lập với DUT**, nhằm tái sử dụng cho nhiều project khác nhau thay vì viết lại Driver, Monitor, Sequence... cho từng thiết kế.

---

# 1. Bài toán đặt ra

Trong một testbench UVM, nếu mỗi DUT có GPIO đều tự viết lại:

```text
Transaction
Sequence
Sequencer
Driver
Monitor
Agent
Coverage
```

thì code sẽ bị lặp lại rất nhiều.

Mục tiêu của project này là đóng gói phần verification của GPIO thành một **UVC – UVM Verification Component** có thể dùng lại:

```text
Project A ─┐
Project B ─┼──> GPIO UVC
Project C ─┘
```

Điểm quan trọng nhất:

> **GPIO UVC không được phụ thuộc vào Counter16, MCU, CPU, FPGA hay một DUT cụ thể nào.**

UVC chỉ hiểu giao tiếp GPIO chuẩn do `gpio_if` cung cấp.

---

# 2. UVM và UVC khác nhau như thế nào?

## UVM

**UVM – Universal Verification Methodology** là framework/phương pháp dùng để xây dựng testbench.

UVM cung cấp các lớp nền như:

```text
uvm_test
uvm_env
uvm_agent
uvm_driver
uvm_monitor
uvm_sequencer
uvm_sequence
uvm_sequence_item
...
```

## UVC

**UVC – UVM Verification Component** là một khối verification cụ thể được xây dựng bằng UVM để phục vụ một giao tiếp/chức năng nhất định.

Trong project này:

```text
UVM
 │
 │ cung cấp framework
 ▼
GPIO UVC
 │
 │ kiểm thử giao tiếp GPIO
 ▼
DUT
```

---

# 3. Kiến trúc tổng thể của GPIO UVC

Luồng kích thích chính:

```text
Sequence
   │
   ▼
Sequencer
   │
   ▼
Driver
   │
   ▼
gpio_if
   │
   ▼
DUT
```

Luồng quan sát:

```text
DUT
 │
 ▼
gpio_if
 │
 ▼
Monitor
 │
 ▼
analysis_port
 ├────────> Scoreboard
 └────────> Coverage
```

Kiến trúc đầy đủ:

```text
                     GPIO UVC
┌────────────────────────────────────────────────┐
│                                                │
│  Sequence                                      │
│  (uvm_object)                                  │
│      │                                         │
│      ▼                                         │
│  ┌──────────── gpio_agent ──────────────────┐  │
│  │                                          │  │
│  │ Sequencer ─────> Driver                  │  │
│  │                    │                     │  │
│  │                    ▼                     │  │
│  │                 gpio_if                  │  │
│  │                    ▲                     │  │
│  │                    │                     │  │
│  │ Monitor ──> analysis_port ──> Coverage   │  │
│  │                                          │  │
│  └──────────────────────────────────────────┘  │
│                                                │
└───────────────────────────┬────────────────────┘
                            │
                            ▼
                     DUT / Adapter
```

## Lưu ý rất quan trọng

`Sequence` **không phải child component của `gpio_agent`**.

`Sequence` kế thừa:

```systemverilog
uvm_sequence #(gpio_seq_item)
```

nên nó là **uvm_object**.

Trong khi đó `gpio_agent` chứa các **uvm_component**:

```text
gpio_agent
├── gpio_sequencer
├── gpio_driver
├── gpio_monitor
└── gpio_coverage   (optional)
```

Sequence được tạo ở test và chạy bằng:

```systemverilog
smoke.start(env.agent.sequencer);
```

---

# 4. Cấu trúc repository

```text
UVC_gpio/
│
├── src/
│   ├── gpio_if.sv
│   ├── gpio_types.sv
│   ├── gpio_config.sv
│   ├── gpio_seq_item.sv
│   ├── gpio_sequencer.sv
│   ├── gpio_driver.sv
│   ├── gpio_monitor.sv
│   ├── gpio_agent.sv
│   ├── gpio_coverage.sv
│   ├── gpio_sequences.sv
│   └── gpio_pkg.sv
│
├── example/
│   ├── gpio_demo_dut.sv
│   ├── gpio_demo_test.sv
│   └── tb_top.sv
│
├── sim/
│   ├── filelist.f
│   ├── run_questa.do
│   └── run_questa.bat
│
└── README.md
```

Ý nghĩa:

| File | Vai trò |
|---|---|
| `gpio_if.sv` | Interface chuẩn giữa UVC và DUT |
| `gpio_config.sv` | Cấu hình UVC |
| `gpio_seq_item.sv` | Transaction của GPIO |
| `gpio_sequencer.sv` | Điều phối transaction |
| `gpio_driver.sv` | Chuyển transaction thành tín hiệu GPIO |
| `gpio_monitor.sv` | Quan sát tín hiệu GPIO |
| `gpio_agent.sv` | Gom Sequencer + Driver + Monitor + Coverage |
| `gpio_sequences.sv` | Các kịch bản stimulus |
| `gpio_coverage.sv` | Functional coverage |
| `gpio_pkg.sv` | Package chung của GPIO UVC |
| `gpio_demo_test.sv` | Test + environment + scoreboard demo |
| `gpio_demo_dut.sv` | DUT loopback dùng để minh họa |
| `tb_top.sv` | Top testbench |

---

# 5. Mô hình GPIO mà UVC đang sử dụng

UVC hiện hỗ trợ tối đa **32 GPIO**.

Trong `gpio_if.sv`:

```systemverilog
logic [31:0] gpio_in;
logic [31:0] gpio_out;
logic [31:0] gpio_oe;
```

Ý nghĩa:

```text
gpio_in
UVC ------------------------> DUT

gpio_out
UVC <------------------------ DUT

gpio_oe
UVC <------------------------ DUT
```

- `gpio_in`: giá trị từ môi trường verification đưa vào DUT.
- `gpio_out`: giá trị DUT xuất ra.
- `gpio_oe`: output-enable/direction do DUT cung cấp.

Ngoài ra còn:

```systemverilog
logic rst_n;
```

và `clk` được đưa vào interface:

```systemverilog
interface gpio_if(input logic clk);
```

---

# 6. Phân tích các đoạn code quan trọng

# 6.1. `gpio_if.sv` – cầu nối giữa UVC và DUT

Đây là lớp kết nối tín hiệu vật lý của UVC.

Phần quan trọng:

```systemverilog
clocking drv_cb @(posedge clk);
  default input #1step output #0;
  input  rst_n;
  output gpio_in;
endclocking
```

Driver sử dụng `drv_cb` để drive:

```text
gpio_in
```

theo cạnh lên của clock.

Monitor có clocking block riêng:

```systemverilog
clocking mon_cb @(posedge clk);
  default input #1step output #0;
  input rst_n;
  input gpio_in;
  input gpio_out;
  input gpio_oe;
endclocking
```

Monitor chỉ **sample**, không drive.

Hai clocking block giúp tách rõ:

```text
Driver  -> ghi tín hiệu
Monitor -> đọc tín hiệu
```

Interface còn cung cấp `modport DUT`:

```systemverilog
modport DUT (
  input  clk,
  input  rst_n,
  input  gpio_in,
  output gpio_out,
  output gpio_oe
);
```

Điều này định nghĩa GPIO theo góc nhìn của DUT.

---

# 6.2. `gpio_config.sv` – làm UVC có thể tái sử dụng

Một UVC muốn reusable thì không nên hard-code mọi thông số.

Project sử dụng:

```systemverilog
uvm_active_passive_enum is_active = UVM_ACTIVE;
int unsigned            num_pins = 16;
bit [31:0]              idle_value = '0;
bit                     monitor_during_reset = 1'b0;
bit                     enable_coverage = 1'b1;
```

## `num_pins`

Cho phép dùng cùng một source UVC cho:

```text
8-bit GPIO
16-bit GPIO
32-bit GPIO
```

mà không phải sửa Driver hay Monitor.

Ví dụ:

```systemverilog
cfg.num_pins = 16;
```

nghĩa là chỉ 16 bit thấp được xem là GPIO hợp lệ.

## `active_mask()`

```systemverilog
function bit [31:0] active_mask();
  if (num_pins >= GPIO_UVC_MAX_WIDTH)
    return 32'hFFFF_FFFF;

  if (num_pins == 0)
    return 32'h0000_0000;

  return (32'h0000_0001 << num_pins) - 1'b1;
endfunction
```

Ví dụ:

```text
num_pins = 8

active_mask =
00000000_00000000_00000000_11111111
```

Nhờ đó Driver chỉ tác động lên các GPIO hợp lệ.

## `is_active`

Agent hỗ trợ hai chế độ:

```text
UVM_ACTIVE
= Sequencer + Driver + Monitor

UVM_PASSIVE
= Monitor
```

Đây là một đặc điểm quan trọng của UVC reusable.

---

# 6.3. `gpio_seq_item.sv` – Transaction của GPIO

Transaction là dữ liệu trao đổi giữa Sequence và Driver.

Các trường stimulus:

```systemverilog
rand bit [31:0] data;
rand bit [31:0] mask;
rand int unsigned hold_cycles;
```

## `data`

Giá trị muốn đưa lên GPIO.

Ví dụ:

```text
data = 0x000000A5
```

## `mask`

Xác định bit nào thực sự được phép thay đổi.

Ví dụ:

```text
data = 1010
mask = 0011
```

thì chỉ 2 bit thấp bị cập nhật.

## `hold_cycles`

Xác định giữ giá trị đó trong bao nhiêu chu kỳ clock.

Constraint:

```systemverilog
constraint c_hold_cycles {
  hold_cycles inside {[1:1024]};
}
```

Ngoài phần stimulus, cùng `gpio_seq_item` còn được Monitor sử dụng để đóng gói dữ liệu quan sát:

```systemverilog
logic [31:0] sample_in;
logic [31:0] sample_out;
logic [31:0] sample_oe;
bit          during_reset;
time         sample_time;
```

Có thể hiểu:

```text
Sequence -> gpio_seq_item -> Driver
Monitor  -> gpio_seq_item -> Scoreboard/Coverage
```

---

# 6.4. `gpio_agent.sv` – lõi cấu trúc của UVC

Đây là file quan trọng nhất để nhìn thấy cây UVC.

Các thành phần:

```systemverilog
gpio_config    cfg;
gpio_sequencer sequencer;
gpio_driver    driver;
gpio_monitor   monitor;
gpio_coverage  coverage;
```

## Monitor luôn tồn tại

Trong `build_phase`:

```systemverilog
monitor = gpio_monitor::type_id::create("monitor", this);
```

Dù ACTIVE hay PASSIVE thì vẫn cần quan sát DUT.

## Coverage là tùy chọn

```systemverilog
if (cfg.enable_coverage) begin
  coverage = gpio_coverage::type_id::create("coverage", this);
end
```

## Driver và Sequencer chỉ được tạo ở ACTIVE mode

```systemverilog
if (cfg.is_active == UVM_ACTIVE) begin
  sequencer = gpio_sequencer::type_id::create("sequencer", this);
  driver    = gpio_driver::type_id::create("driver", this);
end
```

Do đó:

```text
ACTIVE
gpio_agent
├── sequencer
├── driver
├── monitor
└── coverage

PASSIVE
gpio_agent
├── monitor
└── coverage
```

## Kết nối Driver với Sequencer

Trong `connect_phase`:

```systemverilog
driver.seq_item_port.connect(
  sequencer.seq_item_export
);
```

Đây là kết nối tạo nên handshake:

```text
Sequence
   ↓
Sequencer
   ↓
Driver
```

---

# 6.5. `gpio_driver.sv` – biến transaction thành tín hiệu thật

Đây là luồng UVM quan trọng:

```systemverilog
seq_item_port.get_next_item(req);
drive_item(req);
seq_item_port.item_done();
```

Có thể đọc như sau:

```text
1. Driver hỏi Sequencer:
   "Có transaction tiếp theo không?"

2. Nhận req.

3. Drive req xuống gpio_if.

4. Báo:
   "Transaction này đã hoàn thành."
```

Đó chính là handshake giữa Sequencer và Driver.

---

## Xử lý reset

```systemverilog
while (cfg.vif.rst_n !== 1'b1) begin
  @(cfg.vif.drv_cb);
  cfg.vif.drv_cb.gpio_in <= cfg.idle_value;
end
```

Khi reset đang active:

```text
gpio_in = idle_value
```

Driver chưa đưa stimulus mới xuống DUT.

---

## Xử lý mask

```systemverilog
effective_mask = tr.mask & active_mask;
```

Ở đây có hai lớp giới hạn:

```text
transaction mask
       AND
UVC active mask
       ↓
effective_mask
```

Ví dụ:

```text
num_pins = 8

active_mask =
000000FF

tr.mask =
0000000F

effective_mask =
0000000F
```

Sau đó:

```systemverilog
next_value = (next_value & ~effective_mask) |
             (tr.data   &  effective_mask);
```

Ý nghĩa:

> Chỉ thay đổi những bit được mask cho phép; các bit còn lại giữ nguyên.

Đây là một đoạn code rất đáng trình bày vì nó thể hiện UVC không chỉ đơn giản drive toàn bộ bus.

---

# 6.6. `gpio_monitor.sv` – quan sát DUT

Monitor không điều khiển tín hiệu.

Nó chờ cạnh clock:

```systemverilog
@(cfg.vif.mon_cb);
```

sau đó lấy mẫu:

```systemverilog
tr.sample_in  = cfg.vif.mon_cb.gpio_in;
tr.sample_out = cfg.vif.mon_cb.gpio_out;
tr.sample_oe  = cfg.vif.mon_cb.gpio_oe;
```

Cuối cùng:

```systemverilog
ap.write(tr);
```

Luồng:

```text
gpio_if
   ↓
Monitor
   ↓
gpio_seq_item
   ↓
analysis_port
   ├──> Scoreboard
   └──> Coverage
```

Điểm quan trọng:

> Monitor không cần biết DUT là Counter16, MCU hay FPGA. Nó chỉ biết các tín hiệu GPIO chuẩn.

Đây chính là tính reusable.

---

# 6.7. `gpio_sequences.sv` – các kịch bản kích thích

Project hiện có hai loại sequence chính.

## Smoke sequence

```systemverilog
send_value(32'h0000_0000, m);
send_value(m,             m);
send_value(32'hAAAA_AAAA, m);
send_value(32'h5555_5555, m);
```

Các pattern:

```text
All 0
All 1
10101010...
01010101...
```

sau đó chạy **walking-one**:

```systemverilog
for (int unsigned i = 0; i < num_pins; i++)
  send_value(32'h0000_0001 << i, m);
```

Ví dụ 8 bit:

```text
00000001
00000010
00000100
00001000
00010000
00100000
01000000
10000000
```

Pattern này giúp kiểm tra từng GPIO riêng lẻ.

---

## Random sequence

```systemverilog
repeat (num_items) begin
  req = gpio_seq_item::type_id::create("req");

  start_item(req);

  req.randomize();

  req.mask = m;

  finish_item(req);
end
```

Mục đích:

> Sinh nhiều stimulus khác nhau tự động thay vì chỉ test các trường hợp định trước.

---

# 6.8. `gpio_demo_test.sv` – cách tích hợp UVC vào testbench

Test lấy `virtual interface`:

```systemverilog
uvm_config_db#(virtual gpio_if)::get(
  this,
  "",
  "vif",
  vif
);
```

Sau đó tạo config:

```systemverilog
cfg = gpio_config::type_id::create("cfg");

cfg.vif             = vif;
cfg.is_active       = UVM_ACTIVE;
cfg.num_pins        = 16;
cfg.idle_value      = '0;
cfg.enable_coverage = 1'b1;
```

Điểm đáng chú ý:

> Khi chuyển UVC sang project khác, ta chủ yếu thay **configuration**, không sửa code bên trong Driver/Monitor/Agent.

Sau đó config được truyền xuống:

```systemverilog
uvm_config_db#(gpio_config)::set(
  this,
  "env.agent",
  "cfg",
  cfg
);
```

---

# 6.9. Sequence được chạy như thế nào?

Trong `run_phase`:

```systemverilog
smoke = gpio_smoke_seq::type_id::create("smoke");

smoke.num_pins = cfg.num_pins;

smoke.start(env.agent.sequencer);
```

Đây là chỗ thể hiện rõ:

```text
Sequence
    │
    │ start()
    ▼
Sequencer
    │
    ▼
Driver
```

Sau smoke test, project chạy random sequence:

```systemverilog
random_seq.start(env.agent.sequencer);
```

---

# 6.10. Scoreboard demo

Demo DUT hiện là loopback:

```text
gpio_out = gpio_in
```

Vì vậy Scoreboard kiểm tra:

```systemverilog
if ((t.sample_out & m) !==
    (t.sample_in  & m))
```

Nếu đúng:

```text
gpio_out == gpio_in
PASS
```

Nếu sai:

```text
gpio_out != gpio_in
FAIL
```

Scoreboard này chỉ thuộc **demo environment**, không phải phần bắt buộc của reusable GPIO UVC.

Khi dùng UVC với DUT thật, project có thể thay scoreboard bằng reference model phù hợp với DUT đó.

---

# 7. Luồng hoạt động hoàn chỉnh

Có thể tóm tắt toàn bộ project theo 9 bước:

```text
1. Test tạo Sequence
        ↓
2. Sequence tạo gpio_seq_item
        ↓
3. Sequence gửi item cho Sequencer
        ↓
4. Driver nhận item từ Sequencer
        ↓
5. Driver drive gpio_in qua gpio_if
        ↓
6. DUT xử lý
        ↓
7. Monitor sample gpio_in / gpio_out / gpio_oe
        ↓
8. Monitor phát transaction qua analysis_port
        ↓
9. Scoreboard / Coverage nhận transaction
```

Dạng sơ đồ:

```text
gpio_smoke_seq / gpio_random_seq
                │
                ▼
          gpio_sequencer
                │
                ▼
           gpio_driver
                │
                ▼
             gpio_if
                │
                ▼
               DUT
                │
                ▼
             gpio_if
                │
                ▼
          gpio_monitor
                │
                ▼
         analysis_port
           /        \
          /          \
         ▼            ▼
   Scoreboard      Coverage
```

---

# 8. Tại sao UVC này có thể tái sử dụng?

Trong source UVC không có các tín hiệu kiểu:

```text
counter_enable
counter_value
uart_tx
spi_mosi
cpu_state
...
```

UVC chỉ biết:

```text
gpio_in
gpio_out
gpio_oe
clk
rst_n
```

Do đó:

```text
              GPIO UVC
                 │
                 ▼
              gpio_if
                 │
                 ▼
       adapter / wrapper
           (nếu cần)
                 │
                 ▼
                DUT
```

Khi thay DUT:

```text
GPIO UVC       -> giữ nguyên
gpio_if        -> giữ nguyên
config         -> thay theo project
adapter        -> thay nếu DUT cần mapping
scoreboard     -> thay theo chức năng DUT
DUT            -> thay
```

Đây là ý nghĩa chính của **reusable verification component**.

---

# 9. Ví dụ nếu dùng với Counter16

> Phần này là **một hướng tích hợp minh họa**, chưa phải adapter đang có sẵn trong source repo.

Counter16 có thể có các tín hiệu:

```text
enable
reset
count[15:0]
```

Trong khi GPIO UVC hiểu:

```text
gpio_in
gpio_out
gpio_oe
```

Ta có thể viết một adapter riêng:

```text
GPIO UVC
   │
   ▼
gpio_if
   │
   ▼
Counter16 adapter
   │
   ├── gpio_in[0]  -> enable
   ├── reset       -> reset mapping riêng
   └── gpio_out    <- count[15:0]
   │
   ▼
Counter16
```

Điểm quan trọng:

> **Không sửa GPIO UVC thành Counter16 UVC.**

Thay vào đó:

```text
GPIO UVC giữ nguyên
        +
Counter16 adapter
```

Nhờ vậy GPIO UVC vẫn có thể dùng lại cho project khác.

---

# 10. ACTIVE và PASSIVE mode

## ACTIVE mode

```text
gpio_agent
├── Sequencer
├── Driver
├── Monitor
└── Coverage
```

Dùng khi UVC cần:

> **chủ động tạo stimulus cho DUT.**

---

## PASSIVE mode

```text
gpio_agent
├── Monitor
└── Coverage
```

Dùng khi UVC:

> **chỉ quan sát giao tiếp GPIO mà không được phép drive tín hiệu.**

Đây là lý do `gpio_agent` kiểm tra:

```systemverilog
if (cfg.is_active == UVM_ACTIVE)
```

trước khi tạo Driver và Sequencer.

---

# 11. Package của UVC

`gpio_pkg.sv` gom các class UVC:

```systemverilog
package gpio_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "gpio_types.sv"
  `include "gpio_config.sv"
  `include "gpio_seq_item.sv"
  `include "gpio_sequencer.sv"
  `include "gpio_driver.sv"
  `include "gpio_monitor.sv"
  `include "gpio_coverage.sv"
  `include "gpio_agent.sv"
  `include "gpio_sequences.sv"

endpackage
```

Project khác chỉ cần import:

```systemverilog
import gpio_pkg::*;
```

để sử dụng các class của GPIO UVC.

---

# 12. Top testbench

Trong `tb_top.sv`:

```systemverilog
gpio_if gpio_vif(clk);
```

tạo interface thật.

Sau đó đưa virtual interface vào UVM:

```systemverilog
uvm_config_db#(virtual gpio_if)::set(
  null,
  "uvm_test_top",
  "vif",
  gpio_vif
);
```

Có thể hiểu:

```text
SystemVerilog interface thật
          │
          │ config_db
          ▼
virtual interface trong UVM class
          │
          ├── Driver
          └── Monitor
```

Đây là cầu nối giữa:

```text
class-based UVM testbench
        ↕
signal-based DUT
```

---

# 13. Cách chạy trên QuestaSim

Clone repository:

```bash
git clone https://github.com/hoafff/UVC_gpio.git
cd UVC_gpio
```

Trên Windows:

```bat
sim\run_questa.bat
```

Hoặc:

```tcl
vsim -c -do sim/run_questa.do
```

Script sẽ:

```text
1. Tạo thư viện work
2. Tìm UVM
3. Compile source UVC
4. Compile demo DUT + testbench
5. Chạy gpio_demo_test
```

---

# 14. Các pattern đang được test

Smoke sequence:

```text
0000...
1111...
AAAA...
5555...
walking-one
```

Random sequence:

```text
random data
random hold_cycles
```

Do `num_pins` có thể thay đổi nên cùng sequence có thể dùng cho:

```text
GPIO 8 bit
GPIO 16 bit
GPIO 32 bit
```

---

# 15. Những file nên tập trung khi thuyết trình

Nếu chỉ có khoảng **5 phút**, không cần trình bày toàn bộ source.

Nên tập trung vào 5 file sau:

### 1. `gpio_agent.sv`

Cho thấy cấu trúc:

```text
Agent
├── Sequencer
├── Driver
├── Monitor
└── Coverage
```

### 2. `gpio_seq_item.sv`

Cho thấy transaction:

```text
data
mask
hold_cycles
```

### 3. `gpio_driver.sv`

Cho thấy handshake:

```text
get_next_item()
drive_item()
item_done()
```

### 4. `gpio_monitor.sv`

Cho thấy:

```text
sample GPIO
    ↓
analysis_port
```

### 5. `gpio_demo_test.sv`

Cho thấy UVC được cấu hình và sequence được start:

```systemverilog
cfg.num_pins = 16;

smoke.start(
  env.agent.sequencer
);
```

---

# 16. Tóm tắt để trình bày

Có thể giới thiệu project bằng đoạn ngắn:

> **Project xây dựng một GPIO UVC theo UVM với mục tiêu tái sử dụng cho nhiều DUT. UVC gồm transaction, sequence, sequencer, driver, monitor, agent và coverage. Driver nhận transaction từ Sequencer rồi drive gpio_in qua gpio_if; Monitor quan sát gpio_in, gpio_out và gpio_oe rồi gửi transaction qua analysis_port tới Scoreboard hoặc Coverage. UVC không chứa logic đặc thù của DUT, do đó khi chuyển sang project mới ta giữ nguyên UVC và chỉ thay configuration, adapter nếu cần và scoreboard tương ứng.**

---

# 17. Các câu dễ bị hỏi

## UVM và UVC khác nhau ở đâu?

```text
UVM = framework/phương pháp
UVC = verification component được xây bằng UVM
```

---

## Tại sao GPIO UVC reusable?

Vì UVC chỉ phụ thuộc vào:

```text
gpio_if
gpio_config
```

chứ không phụ thuộc tên tín hiệu hay chức năng nội bộ của DUT.

---

## Sequence có nằm trong Agent không?

**Không.**

Sequence là `uvm_object`.

Nó được:

```systemverilog
sequence.start(sequencer);
```

Trong `gpio_agent` chỉ có:

```text
Sequencer
Driver
Monitor
Coverage
```

---

## Driver và Monitor khác nhau ở đâu?

```text
Driver  = chủ động drive stimulus vào DUT
Monitor = chỉ quan sát tín hiệu
```

---

## Scoreboard có phải một phần bắt buộc của GPIO UVC không?

Không.

UVC phát dữ liệu quan sát qua:

```text
analysis_port
```

Environment bên ngoài có thể nối nó tới:

```text
Scoreboard
Coverage
Reference Model
Logger
...
```

---

## Muốn dùng cho DUT khác cần sửa gì?

Thông thường:

```text
GPIO UVC       -> không sửa
configuration  -> thay
adapter        -> thêm/thay nếu cần
scoreboard     -> thay theo DUT
```

---

# 18. Ý tưởng cốt lõi của project

```text
               KHÔNG làm

GPIO UVC phụ thuộc Counter16
GPIO UVC phụ thuộc MCU
GPIO UVC phụ thuộc FPGA


                  MÀ LÀ


             Reusable GPIO UVC
                    │
                    ▼
                 gpio_if
                    │
                    ▼
            Adapter nếu cần
                    │
                    ▼
              DUT bất kỳ
```

> **UVC không đổi – DUT có thể đổi.**

Đó là mục tiêu chính của repository này.
