// Lightweight self-checking helpers, textually included (not a package) so
// each testbench module gets its own private counters. Every unit/core
// testbench ends with tb_summary(), whose final line is the single
// machine-readable pass/fail signal `make test` greps for:
//   TESTBENCH_RESULT: PASS ...
//   TESTBENCH_RESULT: FAIL ...
integer tb_checks = 0;
integer tb_fails  = 0;

task automatic tb_check(input logic cond, input string msg);
  tb_checks = tb_checks + 1;
  if (!cond) begin
    tb_fails = tb_fails + 1;
    $display("  [FAIL] %s", msg);
  end
endtask

task automatic tb_summary(input string name);
  if (tb_fails == 0)
    $display("TESTBENCH_RESULT: PASS (%0d/%0d checks) [%s]", tb_checks, tb_checks, name);
  else
    $display("TESTBENCH_RESULT: FAIL (%0d/%0d checks failed) [%s]", tb_fails, tb_checks, name);
  $finish;
endtask
