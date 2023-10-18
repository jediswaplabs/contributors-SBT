use array::{Array, ArrayTrait, SpanTrait};
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };
use tests::utils::{ deployer_addr, user1, user2, URI};
use contributor_SBT2_0::Master::MonthlyContribution;

#[starknet::interface]
trait IMaster<TContractState> {
    fn get_last_update_id(self: @TContractState) -> u32;
    fn get_dev_points(self: @TContractState, contributor: ContractAddress) -> u32;

    fn update_contibutions(ref self: TContractState,  month_id: u32, contributions: Array::<MonthlyContribution>);

}

#[starknet::interface]
trait IGuildSBT<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn wallet_of_owner(self: @TContractState, account: ContractAddress) -> u256;
    fn get_contribution_tier(self: @TContractState, contributor: ContractAddress) -> u32;
    fn tokenURI(self: @TContractState, token_id: u256) -> Span<felt252>;
    fn get_next_token_id(self: @TContractState) -> u256;


    fn safe_mint(ref self: TContractState, token_type: u8);
}


fn deploy_contracts() -> (ContractAddress, ContractAddress) {
    let mut master_constructor_calldata = Default::default();
    Serde::serialize(@deployer_addr(), ref master_constructor_calldata);
    let master_class = declare('Master');
    let master_address = master_class.deploy(@master_constructor_calldata).unwrap();

    let name = 'Jedi Dev Guild SBT';
    let symbol = 'JEDI-DEV';
    let mut contribution_levels: Array<u32> = ArrayTrait::new();
    contribution_levels.append(100);
    contribution_levels.append(200);
    contribution_levels.append(500);
    contribution_levels.append(1000);

    let mut guildSBT_constructor_calldata = Default::default();
    Serde::serialize(@name, ref guildSBT_constructor_calldata);
    Serde::serialize(@symbol, ref guildSBT_constructor_calldata);
    Serde::serialize(@URI(), ref guildSBT_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref guildSBT_constructor_calldata);
    Serde::serialize(@master_address, ref guildSBT_constructor_calldata);
    Serde::serialize(@contribution_levels, ref guildSBT_constructor_calldata);

    let guildSBT_class = declare('GuildSBT');
    let guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();

    (master_address, guildSBT_address)
}

#[test]
#[should_panic(expected: ('NOT_ENOUGH_POINTS', ))]
fn test_mint_not_enough_contribution_points() { 
    let (_, guildSBT_address) = deploy_contracts();
    let guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: guildSBT_address };

    let balance = guildSBT_dispatcher.balance_of(user1());
    assert(balance == 0, 'invlaid initialisation');

    start_prank(guildSBT_address, user1());
    guildSBT_dispatcher.safe_mint(1);
    stop_prank(guildSBT_address);

}

#[test]
fn test_mint() { 
    let (master_address, guildSBT_address) = deploy_contracts();
    let master_dispatcher = IMasterDispatcher { contract_address: master_address };
    let guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: guildSBT_address };

    let balance = guildSBT_dispatcher.balance_of(user1());
    assert(balance == 0, 'invlaid initialisation');

    let mut contributions: Array<MonthlyContribution> = ArrayTrait::new();
    contributions.append(MonthlyContribution{ contributor: user1(), dev: 240, design: 250, marcom: 20, problem_solving: 30, research: 10});
    contributions.append(MonthlyContribution{ contributor: user2(), dev: 200, design: 30, marcom: 0, problem_solving: 0, research: 50});

    start_prank(master_address, deployer_addr());
    master_dispatcher.update_contibutions(092023, contributions);
    stop_prank(master_address);

    let expected_token_id = guildSBT_dispatcher.get_next_token_id();

    start_prank(guildSBT_address, user1());
    guildSBT_dispatcher.safe_mint(1);
    stop_prank(guildSBT_address);

    let new_balance = guildSBT_dispatcher.balance_of(user1());
    assert(new_balance == 1, 'invalid balance');

    let user1_token_id = guildSBT_dispatcher.wallet_of_owner(user1());
    assert(user1_token_id == expected_token_id, 'Incorrect token id');

    let tokenURI = guildSBT_dispatcher.tokenURI(user1_token_id);
    assert(*tokenURI[0] == 'api.jediswap/', 'Invlalid item 0');
    assert(*tokenURI[1] == 'guildSBT/', 'Invlalid item 1');
    assert(*tokenURI[2] == 'dev/', 'Invlalid item 2');
    assert(*tokenURI[3] == '2', 'Invlalid tier (item 3)');
    assert(*tokenURI[4] == '1', 'Invlalid type (item 4)');
    assert(*tokenURI[5] == '.json', 'Invlalid item 5');
    assert(tokenURI.len() == 6, 'should be 6');

    //verifying token id is updated
    let updated_token_id = guildSBT_dispatcher.get_next_token_id();
    assert(updated_token_id == expected_token_id + 1, 'token id not updated');

}

#[test]
// #[should_panic(expected: ('ALREADY_MINTED', ))]
fn test_mint_second_sbt() { 
    let (master_address, guildSBT_address) = deploy_contracts();
    let master_dispatcher = IMasterDispatcher { contract_address: master_address };
    let guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: guildSBT_address };
    let safe_guildSBT_dispatcher = IGuildSBTSafeDispatcher { contract_address: guildSBT_address };

    let balance = guildSBT_dispatcher.balance_of(user1());
    assert(balance == 0, 'invalid initialisation');

    let mut contributions: Array<MonthlyContribution> = ArrayTrait::new();
    contributions.append(MonthlyContribution{ contributor: user1(), dev: 240, design: 250, marcom: 20, problem_solving: 30, research: 10});
    contributions.append(MonthlyContribution{ contributor: user2(), dev: 200, design: 30, marcom: 0, problem_solving: 0, research: 50});

    start_prank(master_address, deployer_addr());
    master_dispatcher.update_contibutions(092023, contributions);
    stop_prank(master_address);

    start_prank(guildSBT_address, user1());
    safe_guildSBT_dispatcher.safe_mint(1);
    stop_prank(guildSBT_address);

    let new_balance = guildSBT_dispatcher.balance_of(user1());
    assert(new_balance == 1, 'invalid balance');

    start_prank(guildSBT_address, user1());
    match safe_guildSBT_dispatcher.safe_mint(1) {
        Result::Ok(_) => panic_with_felt252('shouldve panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'ALREADY_MINTED', *panic_data.at(0));
        }
    };
    stop_prank(guildSBT_address);

}