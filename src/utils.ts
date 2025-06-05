import { ContractTransactionReceipt } from 'ethers';

export async function txWait (tx: Promise<{ wait: Function }>): Promise<ContractTransactionReceipt> {
    return await (await tx).wait();
}
