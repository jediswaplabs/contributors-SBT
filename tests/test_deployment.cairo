use array::{Array, ArrayTrait, SpanTrait};
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;
use snforge_std::{ declare, ContractClassTrait };
use tests::utils::{ deployer_addr, user1};


#[starknet::interface]
trait IMaster<T> {
    fn owner(self: @T) -> ContractAddress;
}

#[starknet::interface]
trait IGuildSBT<T> {
    fn name(self: @T) -> felt252;
    fn symbol(self: @T) -> felt252;
    fn get_master(self: @T) -> ContractAddress;
    fn owner(self: @T) -> ContractAddress;
    fn baseURI(self: @T) -> Span<felt252>;
    fn get_contribution_levels(self: @T) -> Array<u32>;
    fn get_number_of_levels(self: @T) -> u32;

}

fn URI() -> Span<felt252> {
    let mut uri = ArrayTrait::new();

    uri.append('api.jediswap/');
    uri.append('guildSBT/');
    uri.append('dev/');

    uri.span()
}

#[test]
fn test_deployment_master_guildSBT() { 
    let mut master_constructor_calldata = Default::default();
    Serde::serialize(@deployer_addr(), ref master_constructor_calldata);
    let master_class = declare('Master');
    let master_address = master_class.deploy(@master_constructor_calldata).unwrap();

    let name = 'Jedi Dev Guild SBT';
    let symbol = 'JEDI-DEV';
    let mut contribution_levels = ArrayTrait::new();
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

    // Create a Dispatcher object that will allow interacting with the deployed contract
    let master_dispatcher = IMasterDispatcher { contract_address: master_address };

    let result = master_dispatcher.owner();
    assert(result == deployer_addr(), 'Invalid Owner');

    let guildSBT_dispatcher = IGuildSBTDispatcher { contract_address: guildSBT_address };

    let result = guildSBT_dispatcher.get_master();
    assert(result == master_address, 'Invalid Master');

    let name: felt252 = guildSBT_dispatcher.name();
    assert(name == 'Jedi Dev Guild SBT', 'Invalid name');

    let symbol: felt252 = guildSBT_dispatcher.symbol();
    assert(symbol == 'JEDI-DEV', 'Invalid symbol');

    let baseURI: Span<felt252> = guildSBT_dispatcher.baseURI();
    // TODO: compare span with felt252
    // assert(baseURI == 'api.jediswap/guildSBT/dev/', 'Invalid base uri');

    let owner = guildSBT_dispatcher.owner();
    assert(owner == deployer_addr(), 'Invalid Owner');

    let levels = guildSBT_dispatcher.get_contribution_levels();
    assert(*levels[0] == 100 , 'Invlalid level 0');
    assert(*levels[1] == 200 , 'Invlalid level 1');
    assert(*levels[2] == 500 , 'Invlalid level 2');
    assert(*levels[3] == 1000 , 'Invlalid level 3');

    let number_of_levels = guildSBT_dispatcher.get_number_of_levels();
    assert(number_of_levels == 4, 'Invalid levels');

}