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
use contributor_SBT2_0::Master::Contribution;
use contributor_SBT2_0::Master::TotalMonthlyContribution;

#[starknet::interface]
trait IMaster<TContractState> {
    fn get_last_update_id(self: @TContractState) -> u32;
    fn get_dev_points(self: @TContractState, contributor: ContractAddress) -> u32;
    fn get_contibutions_points(self: @TContractState, contributor: ContractAddress) -> Contribution;
    fn get_contributions_data(self: @TContractState, contributor: ContractAddress) -> Array<u32>;

    fn update_contibutions(ref self: TContractState,  month_id: u32, contributions: Array::<MonthlyContribution>);

///////

}

#[starknet::interface]
trait IGuildSBT<TContractState> {
    fn get_contribution_tier(self: @TContractState, contributor: ContractAddress) -> u32;
    fn get_master(self: @TContractState) -> ContractAddress;
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
fn test_update_contribution_points() { 
    let (master_address, guildSBT_address) = deploy_contracts();
    let master_dispatcher = IMasterDispatcher { contract_address: master_address };
    let guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: guildSBT_address };

    let id1 = master_dispatcher.get_last_update_id();
    assert (id1 == 0, 'Invalid id initialisation');

    let mut contributions: Array<MonthlyContribution> = ArrayTrait::new();
    contributions.append(MonthlyContribution{ contributor: user1(), dev: 120, design: 250, marcom: 20, problem_solving: 30, research: 10});
    contributions.append(MonthlyContribution{ contributor: user2(), dev: 200, design: 30, marcom: 0, problem_solving: 0, research: 50});

    start_prank(master_address, deployer_addr());
    master_dispatcher.update_contibutions(092023, contributions);
    stop_prank(master_address);

    let id2 = master_dispatcher.get_last_update_id();
    assert (id2 == 1, 'invalid id');

    let tier1 = guildSBT_dispatcher.get_contribution_tier(user1());
    assert (tier1 == 1, 'invalid tier1');

    let tier2 = guildSBT_dispatcher.get_contribution_tier(user2());
    assert (tier2 == 2, 'invalid tier2');

}