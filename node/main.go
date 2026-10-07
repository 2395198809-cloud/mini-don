package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"math"
	"math/big"
	"net/http"
	"sort"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

type PriceResult struct {
	Source string
	Price  float64
	Err    error
}

type BinanceTicker struct {
	Price string `json:"price"`
}

type CoinbaseTicker struct {
	Data struct {
		Amount string `json:"amount"`
	} `json:"data"`
}

type KrakenTicker struct {
	Result map[string]struct {
		C []string `json:"c"`
	} `json:"result"`
}

func fetchBinance(ctx context.Context, client *http.Client) (float64, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT", nil)
	if err != nil {
		return 0, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var data BinanceTicker
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, err
	}
	var p float64
	fmt.Sscanf(data.Price, "%f", &p)
	return p, nil
}

func fetchCoinbase(ctx context.Context, client *http.Client) (float64, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://api.coinbase.com/v2/prices/ETH-USD/spot", nil)
	if err != nil {
		return 0, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var data CoinbaseTicker
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, err
	}
	var p float64
	fmt.Sscanf(data.Data.Amount, "%f", &p)
	return p, nil
}

func fetchKraken(ctx context.Context, client *http.Client) (float64, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://api.kraken.com/0/public/Ticker?pair=ETHUSD", nil)
	if err != nil {
		return 0, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var data KrakenTicker
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, err
	}
	for _, v := range data.Result {
		if len(v.C) > 0 {
			var p float64
			fmt.Sscanf(v.C[0], "%f", &p)
			return p, nil
		}
	}
	return 0, fmt.Errorf("kraken data empty")
}

func FetchAllSources(timeout time.Duration) []float64 {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	client := &http.Client{}
	resultsChan := make(chan PriceResult, 3)
	var wg sync.WaitGroup

	fetchers := map[string]func(context.Context, *http.Client) (float64, error){
		"Binance":  fetchBinance,
		"Coinbase": fetchCoinbase,
		"Kraken":   fetchKraken,
	}

	for name, fn := range fetchers {
		wg.Add(1)
		go func(source string, fetchFunc func(context.Context, *http.Client) (float64, error)) {
			defer wg.Done()
			price, err := fetchFunc(ctx, client)
			resultsChan <- PriceResult{Source: source, Price: price, Err: err}
		}(name, fn)
	}

	wg.Wait()
	close(resultsChan)

	var validPrices []float64
	for res := range resultsChan {
		if res.Err == nil && res.Price > 0 {
			validPrices = append(validPrices, res.Price)
		}
	}
	return validPrices
}

func CalculateMedian(prices []float64) (float64, error) {
	if len(prices) == 0 {
		return 0, fmt.Errorf("no prices available")
	}
	sort.Float64s(prices)
	n := len(prices)
	if n%2 == 1 {
		return prices[n/2], nil
	}
	return (prices[n/2-1] + prices[n/2]) / 2.0, nil
}

func FilterOutliers(prices []float64, thresholdRatio float64) ([]float64, error) {
	median, err := CalculateMedian(prices)
	if err != nil {
		return nil, err
	}
	var filtered []float64
	for _, p := range prices {
		deviation := math.Abs(p-median) / median
		if deviation <= thresholdRatio {
			filtered = append(filtered, p)
		}
	}
	return filtered, nil
}

func SignPayload(price *big.Int, timestamp *big.Int, chainId *big.Int, contractAddr common.Address, privKey *ecdsa.PrivateKey) ([]byte, error) {
	var payload []byte
	payload = append(payload, common.LeftPadBytes(price.Bytes(), 32)...)
	payload = append(payload, common.LeftPadBytes(timestamp.Bytes(), 32)...)
	payload = append(payload, common.LeftPadBytes(chainId.Bytes(), 32)...)
	payload = append(payload, contractAddr.Bytes()...)

	messageHash := crypto.Keccak256(payload)
	prefix := fmt.Sprintf("\x19Ethereum Signed Message:\n32")
	ethSignedMessageHash := crypto.Keccak256(append([]byte(prefix), messageHash...))

	sig, err := crypto.Sign(ethSignedMessageHash, privKey)
	if err != nil {
		return nil, err
	}
	if sig[64] < 27 {
		sig[64] += 27
	}
	return sig, nil
}

func main() {
	rawPrivKey := "00000000000000000000000000000000000000000000000000000000000a11ce"
	privKey, err := crypto.HexToECDSA(rawPrivKey)
	if err != nil {
		panic(err)
	}

	signerAddr := crypto.PubkeyToAddress(privKey.PublicKey)
	fmt.Printf("Oracle Node Initialized. Signer Address: %s\n", signerAddr.Hex())

	prices := FetchAllSources(2 * time.Second)
	fmt.Printf("Fetched raw prices: %v\n", prices)

	if len(prices) == 0 {
		prices = []float64{3100.25, 3101.50, 3099.80}
	}

	filteredPrices, err := FilterOutliers(prices, 0.05)
	if err != nil {
		panic(err)
	}

	finalMedian, err := CalculateMedian(filteredPrices)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Aggregated Safe Median Price: $%.2f\n", finalMedian)

	scaledPrice := new(big.Int)
	scaledPrice.SetString(fmt.Sprintf("%.0f", finalMedian*1e18), 10)
	currentTimestamp := big.NewInt(time.Now().Unix())
	chainId := big.NewInt(31337)
	oracleContract := common.HexToAddress("0x5FbDB2315678afecb367f032d93F642f64180aa3")

	signature, err := SignPayload(scaledPrice, currentTimestamp, chainId, oracleContract, privKey)
	if err != nil {
		panic(err)
	}

	fmt.Printf("Signature Generated (Hex): 0x%x\n", signature)
	fmt.Printf("Ready to submit to EVM Contract via RPC.\n")
}
