use array::{Array, ArrayTrait, SpanTrait};
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };
use tests::utils::{ deployer_addr, user1, user2, user3, user4, URI};
use contributor_SBT2_0::attribution::Contribution;
use contributor_SBT2_0::attribution::MonthlyContribution;

#[starknet::interface]
trait IAttribution<TContractState> {
    fn get_last_update_id(self: @TContractState) -> u32;
    fn get_contributions_points(self: @TContractState, contributor: ContractAddress) -> Array<Contribution>;
    fn get_contributions_data(self: @TContractState, contributor: ContractAddress, guild: felt252) -> Array<u32>;
    fn get_guild_total_contribution(self: @TContractState, month_id: u32, guild: felt252) -> u32;
    
    fn update_contibutions(ref self: TContractState, month_id: u32, guild: felt252, contributions: Array::<MonthlyContribution>);
    fn initialise(ref self: TContractState, guilds_name: Array::<felt252>, guilds_address: Array::<ContractAddress>);


///////

}

#[starknet::interface]
trait IGuildSBT<TContractState> {
    fn get_contribution_tier(self: @TContractState, contributor: ContractAddress) -> u32;
    fn get_master(self: @TContractState) -> ContractAddress;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn wallet_of_owner(self: @TContractState, account: ContractAddress) -> u256;
    fn tokenURI(self: @TContractState, token_id: u256) -> Span<felt252>;
    fn get_next_token_id(self: @TContractState) -> u256;

    fn safe_mint(ref self: TContractState, token_type: u8);
}


fn deploy_contracts() -> (ContractAddress, ContractAddress) {
    let mut attribution_constructor_calldata = Default::default();
    Serde::serialize(@deployer_addr(), ref attribution_constructor_calldata);
    let attribution_class = declare('Attribution');
    let attribution_address = attribution_class.deploy(@attribution_constructor_calldata).unwrap();

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
    Serde::serialize(@attribution_address, ref guildSBT_constructor_calldata);
    Serde::serialize(@contribution_levels, ref guildSBT_constructor_calldata);

    let guildSBT_class = declare('GuildSBT');
    let guildSBT_address = guildSBT_class.deploy(@guildSBT_constructor_calldata).unwrap();

    let attribution_dispatcher = IAttributionDispatcher { contract_address: attribution_address };

    let mut guilds_name: Array<felt252> = ArrayTrait::new();
    guilds_name.append('dev');
    guilds_name.append('design');

    let mut guilds_address: Array<ContractAddress> = ArrayTrait::new();
    guilds_address.append(guildSBT_address);
    guilds_address.append(guildSBT_address);

    start_prank(attribution_address, deployer_addr());
    attribution_dispatcher.initialise(guilds_name, guilds_address);
    stop_prank(attribution_address);
    (attribution_address, guildSBT_address)
}

#[test]
fn test_update_contribution_points() { 
    let (attribution_address, guildSBT_address) = deploy_contracts();
    let attribution_dispatcher = IAttributionDispatcher { contract_address: attribution_address };
    let guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: guildSBT_address };

    let id1 = attribution_dispatcher.get_last_update_id();
    assert (id1 == 0, 'Invalid id initialisation');

    let month_id: u32 = 092023;
    let dev_guild = 'dev';
    let design_guild = 'design';

    let user1_contribution_dev = MonthlyContribution{ contributor: user1(), point: 120};
    let user2_contribution_dev = MonthlyContribution{ contributor: user2(), point: 200};
    let user3_contribution_dev = MonthlyContribution{ contributor: user3(), point: 30};
    let mut contributions_dev: Array<MonthlyContribution> = ArrayTrait::new();
    contributions_dev.append(user1_contribution_dev);
    contributions_dev.append(user2_contribution_dev);
    contributions_dev.append(user3_contribution_dev);

    let user1_contribution_design = MonthlyContribution{ contributor: user1(), point: 10};
    let user2_contribution_design = MonthlyContribution{ contributor: user2(), point: 105};
    let user3_contribution_design = MonthlyContribution{ contributor: user3(), point: 250};
    let mut contributions_design: Array<MonthlyContribution> = ArrayTrait::new();
    contributions_design.append(user1_contribution_design);
    contributions_design.append(user2_contribution_design);
    contributions_design.append(user3_contribution_design);


    // let mut spy = spy_events(SpyOn::One(attribution_address));

    start_prank(attribution_address, deployer_addr());
    attribution_dispatcher.update_contibutions(month_id, dev_guild, contributions_dev);
    attribution_dispatcher.update_contibutions(month_id, design_guild, contributions_design);
    stop_prank(attribution_address);

    // let mut user1_event_data = Default::default();
    // Serde::serialize(@id1, ref user1_event_data);
    // Serde::serialize(@user1(), ref user1_event_data);
    // Serde::serialize(@month_id, ref user1_event_data);
    // Serde::serialize(@dev_guild, ref user1_event_data);
    // Serde::serialize(@user1_contribution, ref user1_event_data);
    // spy.assert_emitted(@array![
    //     Event { from: attribution_address, name: 'ContributionUpdated', keys: array![], data: user1_event_data }
    // ]);

    // let mut user2_event_data = Default::default();
    // Serde::serialize(@id1, ref user2_event_data);
    // Serde::serialize(@user2(), ref user2_event_data);
    // Serde::serialize(@month_id, ref user2_event_data);
    // Serde::serialize(@dev_guild, ref user1_event_data);
    // Serde::serialize(@user2_contribution, ref user2_event_data);
    // spy.assert_emitted(@array![
    //     Event { from: attribution_address, name: 'ContributionUpdated', keys: array![], data: user2_event_data }
    // ]);

    // let mut user3_event_data = Default::default();
    // Serde::serialize(@id1, ref user3_event_data);
    // Serde::serialize(@user3(), ref user3_event_data);
    // Serde::serialize(@month_id, ref user3_event_data);
    // Serde::serialize(@dev_guild, ref user1_event_data);
    // Serde::serialize(@user3_contribution, ref user3_event_data);
    // spy.assert_emitted(@array![
    //     Event { from: attribution_address, name: 'ContributionUpdated', keys: array![], data: user3_event_data }
    // ]);

    let id2 = attribution_dispatcher.get_last_update_id();
    assert (id2 == 2, 'invalid id');

    // verifying points for user 1 is updated
    let user1_points = attribution_dispatcher.get_contributions_points(user1());
    assert(user1_points.len() == 2, 'invalid point length');
    assert(*user1_points.at(0).cum_point == 120, 'invalid dev point');
    assert(*user1_points.at(1).cum_point == 10, 'invalid design point');


    // verifying points for user 2 is updated
    let user2_points = attribution_dispatcher.get_contributions_points(user2());
    assert(*user2_points.at(0).cum_point == 200, 'invalid dev point');
    assert(*user2_points.at(1).cum_point == 105, 'invalid design point');

    // verifying contribution data(Montly) is updated
    let mut dev_data = attribution_dispatcher.get_contributions_data(user1(), 'dev');
    assert(dev_data.len() == 2, 'invalid length');
    assert(*dev_data[0] == month_id, 'invalid month id');
    assert(*dev_data[1] == 120, 'invalid month points');

    let mut design_data = attribution_dispatcher.get_contributions_data(user1(), 'design');
    assert(design_data.len() == 2, 'invalid length');
    assert(*design_data[0] == month_id, 'invalid month id');
    assert(*design_data[1] == 10, 'invalid month points');


    // verifying tier for each levels
    let tier_user1 = guildSBT_dispatcher.get_contribution_tier(user1());
    assert (tier_user1 == 1, 'invalid tier_user1');

    let tier_user2 = guildSBT_dispatcher.get_contribution_tier(user2());
    assert (tier_user2 == 2, 'invalid tier_user2');


    // verifying total monthly contribution
    let total_contribution_point_dev = attribution_dispatcher.get_guild_total_contribution(month_id, dev_guild);
    assert(total_contribution_point_dev == 350, 'incorrect total dev');
    
    // verifying total monthly contribution
    let total_contribution_point_design = attribution_dispatcher.get_guild_total_contribution(month_id, design_guild);
    assert(total_contribution_point_design == 365, 'incorrect total design');
    


}