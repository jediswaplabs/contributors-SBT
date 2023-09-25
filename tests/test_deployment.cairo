%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IMaster {
    func owner() -> (owner: felt) {
    }
}

@contract_interface
namespace IGuildSBT {
    func owner() -> (owner: felt) {
    }

    func master() -> (master: felt) {
    }

    func number_of_tiers() -> (res: felt) {
    }

    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func baseURI() -> (res: felt) {
    }
}

@external
func __setup__() {
    alloc_locals;

    tempvar deployer_address = 123456789;

    %{
        context.deployer_address = ids.deployer_address
        context.master = deploy_contract("./contracts/master.cairo", [context.deployer_address]).contract_address
    %}

    return ();
}

@external
func test_master{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    tempvar master;
    tempvar deployer_address;

    %{
        ids.deployer_address = context.deployer_address        
        ids.master = context.master
    %}

    let (res) = IMaster.owner(contract_address=master);
    assert res = deployer_address;

    return ();
}

@external
func test_guildSBT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    tempvar master;
    tempvar deployer_address;
    tempvar contract_address;

    %{
        ids.deployer_address = context.deployer_address        
        ids.master = context.master
        context.contract_address = deploy_contract("./contracts/guildSBT.cairo", [context.deployer_address, 0x6170692e6a656469737761702f6775696c645342542f64657369676e2f, context.master]).contract_address
        ids.contract_address = context.contract_address
    %}

    let (res) = IGuildSBT.owner(contract_address=contract_address);
    assert res = deployer_address;

    let (res) = IGuildSBT.master(contract_address=contract_address);
    assert res = master;

    let (res) = IGuildSBT.number_of_tiers(contract_address=contract_address);
    assert res = 5;

    let (res) = IGuildSBT.name(contract_address=contract_address);
    assert res = 'Design Guild SBT';

    let (res) = IGuildSBT.symbol(contract_address=contract_address);
    assert res = 'DESIGN';

    let (res) = IGuildSBT.baseURI(contract_address=contract_address);
    assert res = 'api.jediswap/guildSBT/design/';

    return ();
}
