// Dynamically import node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

async function estimateGas(params) {
    try {
        const raw = JSON.stringify({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_estimateRip7560TransactionGas",
            "params": [params, "latest"]
        });

        const requestOptions = {
            method: "POST",
            headers: {'Content-Type': 'application/json'},
            body: raw,
            redirect: "follow"
        };

        const response = await fetch("http://127.0.0.1:38545", requestOptions);
        const responseData = await response.json();

        if (response.ok) {
            const totalGas = parseInt(responseData.result.validationGas, 16) + parseInt(responseData.result.executionGas, 16);
            console.log(`${totalGas}`);
        } else {
            console.error('HTTP Error:', responseData);
        }
    } catch (error) {
        console.error('Error making RPC call:', error.message);
    }
}

const params = process.argv[2];
if (!params) {
    console.error("Please provide the parameters as a JSON string.");
    process.exit(1);
}

try {
    const parsedParams = JSON.parse(params);
    estimateGas(parsedParams);
} catch (error) {
    console.error("Failed to parse parameters:", error.message);
}
