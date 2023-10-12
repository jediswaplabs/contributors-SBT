use starknet:: { ContractAddress, contract_address_try_from_felt252, contract_address_const };


fn deployer_addr() -> ContractAddress {
    contract_address_try_from_felt252('deployer').unwrap()
}


fn zero_addr() -> ContractAddress {
    contract_address_const::<0>()
}

fn user1() -> ContractAddress {
    contract_address_try_from_felt252('user1').unwrap()
}

fn user2() -> ContractAddress {
    contract_address_try_from_felt252('user2').unwrap()
}

fn user3() -> ContractAddress {
    contract_address_try_from_felt252('user3').unwrap()
}

fn user4() -> ContractAddress {
    contract_address_try_from_felt252('user4').unwrap()
}