//https://aptos.dev/en/build/smart-contracts/fungible-asset
//https://aptos.dev/en/build/guides/first-fungible-asset#step-433-managing-a-coin

//https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples/fungible_asset
//https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/move-examples/fungible_asset/fa_coin/sources/FACoin.move
module publisher::fungible_asset {
  use aptos_framework::fungible_asset::{
    Self,
    MintRef,
    TransferRef,
    BurnRef,
    Metadata,
    FungibleAsset
  }; //transfer/withdraw/deposit: Move between  unfrozen fungible stores objects
  use aptos_framework::object::{Self, Object};
  use aptos_framework::primary_fungible_store; //::{transfer/withdraw/deposit}: Move FA between unfrozen primary stores of different accounts.
  //use std::error;
  use std::signer;
  use std::string::utf8;
  use std::option;
  //use std::error;

  const ENOT_OWNER: u64 = 1;
  const EPAUSED: u64 = 2;
  const ASSET_SYMBOL: vector<u8> = b"UNCN";

  #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
  /// Hold refs to control the minting, transfer and burning of fungible assets.
  struct FaStore has key {
    mint_ref: MintRef,
    transfer_ref: TransferRef,
    burn_ref: BurnRef,
    paused: bool
  }

  // Make sure the `signer` is an address you own.
  fun init_module(admin: &signer) {
    //generate metadata object
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL); //or &create_sticky_object(admin)
    //ConstructorRef cannot be stored and is destroyed by the end of the transaction used to create this Object, so any Refs must be generated during Object creation.

    primary_fungible_store::create_primary_store_enabled_fungible_asset(
      constructor_ref,
      option::none(), /*maximum_supply: option<u128>*/
      utf8(b"Unicorn Coin"), /* name */
      utf8(ASSET_SYMBOL), /* symbol */
      8, /* decimals u8 */
      utf8(
        b"https://peach-tough-crayfish-991.mypinata.cloud/ipfs/QmWv9vn1QG2NJ1mFTsZ1sCr48zkmb9kmYQjYJnxSSmuMCj"
      ), /* icon_uri */
      utf8(
        b"https://github.com/AuroraLantean/Aptos_demo"
      ) /* project_uri */
    ); //Alternatively, you can use add_fungibility which uses the same parameters, but requires recipients to keep track of their FungibleStore addresses to keep track of how many units of your FA they have.
    /*let converted_max_supply = if (option::is_some(&max_supply)) {
        option::some(
            option::extract(&mut max_supply) * math128::pow(10, (decimals as u128))
        )
    } else {
        option::none()
    };*/

    // Generate mint/burn/transfer refs. All Refs must be generated when the Object is created as that is the only time you can generate an Objects ConstructorRef.
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref); // Used by fungible_asset::mint() and fungible_asset::mint_to()

    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref); // Used by fungible_asset::burn() and fungible_asset::burn_from()

    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref); // Used by fungible_asset::set_frozen_flag(), fungible_asset::withdraw_with_ref(),
    // fungible_asset::deposit_with_ref(), and fungible_asset::transfer_with_ref().

    let fa_ref_signer = object::generate_signer(constructor_ref);
    move_to(
      &fa_ref_signer,
      FaStore { mint_ref, transfer_ref, burn_ref, paused: false }
    )
    /*// Override the deposit and withdraw functions which mean overriding transfer.
        // This ensures all transfer will call withdraw and deposit functions in this module
        // and perform the necessary checks.
        // This is OPTIONAL. It is an advanced feature and we don't NEED a global state to pause the FA coin.
        let deposit = function_info::new_function_info(
            admin,
            string::utf8(b"fa_coin"),
            string::utf8(b"deposit"),
        );
        let withdraw = function_info::new_function_info(
            admin,
            string::utf8(b"fa_coin"),
            string::utf8(b"withdraw"),
        );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none(),
        );
    */
  }

  #[view]
  public fun get_metadata_object(): Object<Metadata> {
    let metadata_addr = object::create_object_address(&@publisher, ASSET_SYMBOL);
    object::address_to_object<Metadata>(metadata_addr)
  }

  #[view]
  public fun get_balance(target: address): u64 {
    let metadata = get_metadata_object();
    primary_fungible_store::balance(target, metadata)
  }

  public entry fun mint(admin: &signer, to: address, amount: u64) acquires FaStore {
    let metadata = get_metadata_object();
    let fa_store = authorized_borrow_refs(admin, metadata);

    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, metadata);

    //let decimals = fungible_asset::decimals(metadata);

    let bucket = fungible_asset::mint(&fa_store.mint_ref, amount);
    //primary_fungible_store::mint(&fa_store.mint_ref, to, amount * math64::pow(10, (decimals as u64)))

    fungible_asset::deposit_with_ref(&fa_store.transfer_ref, to_wallet, bucket);
  }

  /// to verify the signer is the object's admin.
  inline fun authorized_borrow_refs(
    admin: &signer, object: Object<Metadata>
  ): &FaStore acquires FaStore {
    assert!(object::is_owner(object, signer::address_of(admin)), ENOT_OWNER); //error::permission_denied(
    borrow_global<FaStore>(object::object_address(&object))
  }

  public entry fun transfer(
    admin: &signer, from: address, to: address, amount: u64
  ) acquires FaStore {
    let asset = get_metadata_object();

    let fa_store = authorized_borrow_refs(admin, asset);

    let from_wallet = primary_fungible_store::primary_store(from, asset);

    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

    fungible_asset::transfer_with_ref(
      &fa_store.transfer_ref,
      from_wallet,
      to_wallet,
      amount
    );
  }

  public entry fun burn(admin: &signer, from: address, amount: u64) acquires FaStore {
    let asset = get_metadata_object();

    let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;

    let from_wallet = primary_fungible_store::primary_store(from, asset);

    fungible_asset::burn_from(burn_ref, from_wallet, amount);
  }

  //to ensure that the account is not denylisted
  public fun withdraw(admin: &signer, amount: u64, from: address): FungibleAsset acquires FaStore {
    let asset = get_metadata_object();

    let fa_store = authorized_borrow_refs(admin, asset);
    assert!(!fa_store.paused, EPAUSED);

    let from_wallet = primary_fungible_store::primary_store(from, asset);

    fungible_asset::withdraw_with_ref(&fa_store.transfer_ref, from_wallet, amount)
  }

  //to ensure that the account is not denylisted
  public fun deposit(admin: &signer, to: address, fa: FungibleAsset) acquires FaStore {
    let asset = get_metadata_object();

    let fa_store = authorized_borrow_refs(admin, asset);
    assert!(!fa_store.paused, EPAUSED);

    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

    fungible_asset::deposit_with_ref(&fa_store.transfer_ref, to_wallet, fa);
  }

  public entry fun freeze_unfreeze_account(
    admin: &signer, target: address, boo: bool
  ) acquires FaStore {
    let asset = get_metadata_object();

    let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;

    let wallet = primary_fungible_store::ensure_primary_store_exists(target, asset);

    fungible_asset::set_frozen_flag(transfer_ref, wallet, boo);
  }

  //use aptos_std::string_utils::{format1, format2};
  //#[test_only]
  //use aptos_std::string_utils::format1;
  //print(&format1(&b"list_owner: {}", list_owner));

  #[test(owner_sp = @publisher)]
  fun test_fungible_asset1(owner_sp: &signer) acquires FaStore {
    init_module(owner_sp);
    let owner = signer::address_of(owner_sp);
    let user1 = @0xface;

    mint(owner_sp, owner, 100);
    let metadata = get_metadata_object();
    assert!(get_balance(owner) == 100, 4);

    freeze_unfreeze_account(owner_sp, owner, true);
    assert!(primary_fungible_store::is_frozen(owner, metadata), 5);

    //admin overrides frozen account
    transfer(owner_sp, owner, user1, 10);
    assert!(get_balance(user1) == 10, 6);

    freeze_unfreeze_account(owner_sp, owner, false);
    assert!(!primary_fungible_store::is_frozen(owner, metadata), 7);
    burn(owner_sp, owner, 90);
  }

  #[test(owner_sp = @publisher, user1 = @0xface)]
  #[expected_failure(abort_code = ENOT_OWNER)]
  fun test_fungible_asset2(owner_sp: &signer, user1: &signer) acquires FaStore {
    init_module(owner_sp);
    let owner = signer::address_of(owner_sp);
    mint(user1, owner, 100);
  }
}
/* Events
struct Deposit has drop, store {
    store: address,
    amount: u64,
}
struct Withdraw has drop, store {
    store: address,
    amount: u64,
}
struct Frozen has drop, store {
    store: address,
    frozen: bool,
}

https://aptos.dev/en/build/guides/first-fungible-asset#step-43-understanding-the-management-primitives-of-facoin
// Override the deposit and withdraw functions which mean overriding transfer.
// This ensures all transfer will call withdraw and deposit functions in this module
// and perform the necessary checks.
  let deposit = function_info::new_function_info(admin, string::utf8(b"fa_coin"), string::utf8(b"deposit"));

  let withdraw = function_info::new_function_info(admin, string::utf8(b"fa_coin"),         string::utf8(b"withdraw"));

  dispatchable_fungible_asset::register_dispatch_functions(
        constructor_ref,
        option::some(withdraw),
        option::some(deposit),
        option::none(),
  );*/
