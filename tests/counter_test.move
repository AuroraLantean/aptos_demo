#[test_only]
module publisher::counter_tests {
  use std::signer;
  use std::unit_test;
  use std::vector;
  //use std::debug::print;
  //use std::string::{utf8, String};
  use std::timestamp;
  use publisher::counter;

  const DNOT_EXIST: u64 = 100;
  const DNOT_INCREASE: u64 = 101;

  fun get_account(): signer {
    vector::pop_back(&mut unit_test::create_signers_for_testing(1))
  }

  #[test]
  public entry fun test_if_it_init() {
    let account = get_account();
    let sender = signer::address_of(&account);
    aptos_framework::account::create_account_for_test(sender);
    //Your tests...
  }

  #[test(signr = @0x1)]
  fun test_time(signr: signer) {
    // set up global time for testing purpose
    timestamp::set_time_has_started_for_testing(&signr);
    counter::time();
  }
}
