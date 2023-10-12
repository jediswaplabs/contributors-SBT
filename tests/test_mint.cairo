use array::{Array, ArrayTrait, SpanTrait};
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };
use tests::utils::{ deployer_addr, user1, user2};
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

    fn safe_mint(ref self: TContractState, token_type: u8);
}


fn URI() -> Span<felt252> {
    let mut uri = ArrayTrait::new();

    uri.append('api.jediswap/');
    uri.append('guildSBT/');
    uri.append('dev/');

    uri.span()
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

    start_prank(guildSBT_address, user1());
    guildSBT_dispatcher.safe_mint(1);
    stop_prank(guildSBT_address);

    let new_balance = guildSBT_dispatcher.balance_of(user1());
    assert(new_balance == 1, 'invalid balance');

    let user1_token_id = guildSBT_dispatcher.wallet_of_owner(user1());

    let tokenURI = guildSBT_dispatcher.tokenURI(user1_token_id);
    // TODO: comapre span to string
    // assert(tokenURI == 'api.jediswap/guildSBT/dev/21', 'invalid uri');

}

#[test]
#[should_panic(expected: ('ALREADY_MINTED', ))]
fn test_mint_second_sbt() { 
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

    start_prank(guildSBT_address, user1());
    guildSBT_dispatcher.safe_mint(1);
    stop_prank(guildSBT_address);

    let new_balance = guildSBT_dispatcher.balance_of(user1());
    assert(new_balance == 1, 'invalid balance');

    start_prank(guildSBT_address, user1());
    guildSBT_dispatcher.safe_mint(1);
    stop_prank(guildSBT_address);

}