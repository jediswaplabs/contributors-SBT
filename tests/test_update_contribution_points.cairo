use array::{Array, ArrayTrait, SpanTrait};
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };
use tests::utils::{ deployer_addr, user1, user2, user3, user4, URI};
use contributor_SBT2_0::Master::MonthlyContribution;
use contributor_SBT2_0::Master::Contribution;
use contributor_SBT2_0::Master::TotalMonthlyContribution;

#[starknet::interface]
trait IMaster<TContractState> {
    fn get_last_update_id(self: @TContractState) -> u32;
    fn get_dev_points(self: @TContractState, contributor: ContractAddress) -> u32;
    fn get_contributions_points(self: @TContractState, contributor: ContractAddress) -> Contribution;
    fn get_contributions_data(self: @TContractState, contributor: ContractAddress, guild: felt252) -> Array<u32>;
    fn get_total_contribution(self: @TContractState, month_id: u32) -> TotalMonthlyContribution;


    fn update_contibutions(ref self: TContractState,  month_id: u32, contributions: Array::<MonthlyContribution>);

///////

}

#[starknet::interface]
trait IGuildSBT<TContractState> {
    fn get_contribution_tier(self: @TContractState, contributor: ContractAddress) -> u32;
    fn get_master(self: @TContractState) -> ContractAddress;
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

    let month_id: u32 = 092023;

    let user1_contribution = MonthlyContribution{ contributor: user1(), dev: 120, design: 250, marcom: 20, problem_solving: 0, research: 10};
    let user2_contribution = MonthlyContribution{ contributor: user2(), dev: 200, design: 30, marcom: 0, problem_solving: 0, research: 50};
    let user3_contribution = MonthlyContribution{ contributor: user3(), dev: 30, design: 100, marcom: 0, problem_solving: 0, research: 50};
    let user4_contribution = MonthlyContribution{ contributor: user4(), dev: 1500, design: 0, marcom: 25, problem_solving: 0, research: 100};
    let mut contributions: Array<MonthlyContribution> = ArrayTrait::new();
    contributions.append(user1_contribution);
    contributions.append(user2_contribution);
    contributions.append(user3_contribution);
    contributions.append(user4_contribution);

    let mut spy = spy_events(SpyOn::One(master_address));

    start_prank(master_address, deployer_addr());
    master_dispatcher.update_contibutions(month_id, contributions);
    stop_prank(master_address);

    let mut user1_event_data = Default::default();
    Serde::serialize(@id1, ref user1_event_data);
    Serde::serialize(@user1(), ref user1_event_data);
    Serde::serialize(@month_id, ref user1_event_data);
    Serde::serialize(@user1_contribution, ref user1_event_data);
    spy.assert_emitted(@array![
        Event { from: master_address, name: 'ContributionUpdated', keys: array![], data: user1_event_data }
    ]);

    let mut user2_event_data = Default::default();
    Serde::serialize(@id1, ref user2_event_data);
    Serde::serialize(@user2(), ref user2_event_data);
    Serde::serialize(@month_id, ref user2_event_data);
    Serde::serialize(@user2_contribution, ref user2_event_data);
    spy.assert_emitted(@array![
        Event { from: master_address, name: 'ContributionUpdated', keys: array![], data: user2_event_data }
    ]);

    let mut user3_event_data = Default::default();
    Serde::serialize(@id1, ref user3_event_data);
    Serde::serialize(@user3(), ref user3_event_data);
    Serde::serialize(@month_id, ref user3_event_data);
    Serde::serialize(@user3_contribution, ref user3_event_data);
    spy.assert_emitted(@array![
        Event { from: master_address, name: 'ContributionUpdated', keys: array![], data: user3_event_data }
    ]);

    let mut user4_event_data = Default::default();
    Serde::serialize(@id1, ref user4_event_data);
    Serde::serialize(@user4(), ref user4_event_data);
    Serde::serialize(@month_id, ref user4_event_data);
    Serde::serialize(@user4_contribution, ref user4_event_data);
    spy.assert_emitted(@array![
        Event { from: master_address, name: 'ContributionUpdated', keys: array![], data: user4_event_data }
    ]);

    let id2 = master_dispatcher.get_last_update_id();
    assert (id2 == 1, 'invalid id');

    // verifying points for user 1 is updated
    let mut points = master_dispatcher.get_contributions_points(user1());
    assert(points.dev == 120, 'invalid dev point');
    assert(points.design == 250, 'invalid design point');
    assert(points.marcom == 20, 'invalid marcom point');
    assert(points.problem_solving == 0, 'invalid problem solving point');
    assert(points.research == 10, 'invalid research point');

    // verifying points for user 4 is updated
    points = master_dispatcher.get_contributions_points(user4());
    assert(points.dev == 1500, 'invalid dev point');
    assert(points.design == 0, 'invalid design point');
    assert(points.marcom == 25, 'invalid marcom point');
    assert(points.problem_solving == 0, 'invalid problem solving point');
    assert(points.research == 100, 'invalid research point');

    // verifying contribution data(Montly) is updated
    let mut dev_data = master_dispatcher.get_contributions_data(user1(), 'dev');
    assert(dev_data.len() == 2, 'invalid length');
    assert(*dev_data[0] == month_id, 'invalid month id');
    assert(*dev_data[1] == 120, 'invalid month points');

    let mut design_data = master_dispatcher.get_contributions_data(user1(), 'design');
    assert(design_data.len() == 2, 'invalid length');
    assert(*design_data[0] == month_id, 'invalid month id');
    assert(*design_data[1] == 250, 'invalid month points');

    let mut marcom_data = master_dispatcher.get_contributions_data(user1(), 'marcom');
    assert(marcom_data.len() == 2, 'invalid length');
    assert(*marcom_data[0] == month_id, 'invalid month id');
    assert(*marcom_data[1] == 20, 'invalid month points');

    let mut problem_solving_data = master_dispatcher.get_contributions_data(user1(), 'problem_solving');
    assert(problem_solving_data.len() == 0, 'invalid length');

    let mut research_data = master_dispatcher.get_contributions_data(user1(), 'research');
    assert(research_data.len() == 2, 'invalid length');
    assert(*research_data[0] == month_id, 'invalid month id');
    assert(*research_data[1] == 10, 'invalid month points');


    // verifying tier for each levels
    let tier_user1 = guildSBT_dispatcher.get_contribution_tier(user1());
    assert (tier_user1 == 1, 'invalid tier_user1');

    let tier_user2 = guildSBT_dispatcher.get_contribution_tier(user2());
    assert (tier_user2 == 2, 'invalid tier_user2');

    let tier_user3 = guildSBT_dispatcher.get_contribution_tier(user3());
    assert (tier_user3 == 0, 'invalid tier_user3');

    let tier_user4 = guildSBT_dispatcher.get_contribution_tier(user4());
    assert (tier_user4 == 4, 'invalid tier_user4');

    // verifying total monthly contribution
    let total_contribution_point = master_dispatcher.get_total_contribution(month_id);
    assert(total_contribution_point.dev == 1850, 'incorrect total dev');
    assert(total_contribution_point.design == 380, 'incorrect total design');
    assert(total_contribution_point.marcom == 45, 'incorrect total marcom');
    assert(total_contribution_point.problem_solving == 0, 'incorrect total problem solving');
    assert(total_contribution_point.research == 210, 'incorrect total research');


}