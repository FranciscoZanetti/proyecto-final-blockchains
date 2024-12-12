build:
	forge build

test:
	forge test

deploy-busd:
	forge script script/DeployBUSD.s.sol:DeployBUSD --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY_HEXA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_PROYECTO_FINAL_API_KEY)

deploy-ccnft:
	forge script script/DeployCCNFT.s.sol:DeployCCNFT --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY_HEXA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_PROYECTO_FINAL_API_KEY)

.PHONY: build test deploy-busd deploy-ccnft