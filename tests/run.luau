local testlib = require("./testlib")

require("./closure_diff_test")
require("./nix_test")
require("./service_generation_test")

testlib.run()
