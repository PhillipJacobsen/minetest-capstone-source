#include <string>
#include <iostream>
#include <vector>
#include <array>
#include <cstring>

#include "solar/crypto.h"
#include "solar/wordlist.h"

#include "solar/lib/libtorsion/include/torsion/ecc.h"
#include "solar/lib/libtorsion/include/torsion/hash.h"
#include "solar/lib/libtorsion/include/torsion/rand.h"
#include "solar/lib/libtorsion/include/torsion/drbg.h"
#include "solar/lib/libtorsion/include/torsion/encoding.h"

#include "solar/lib/bcl/src/Ripemd160.hpp"
#include "solar/lib/bcl/src/Base58Check.hpp"
#include "solar/lib/bcl/src/Sha256.hpp"

void generate_random_bytes(unsigned char *bytes, size_t size) {
	torsion_getentropy(bytes, size);
}

std::string bytes_to_entropy(unsigned char *bytes, size_t size) {
	std::string entropy;

	for (int i = 0; i < size; i++) {
		entropy.append(decimal_to_binary(bytes[i]));
	}

	return entropy;
}

std::string decimal_to_binary(int decimal) {
	std::string binary;

	for (int i = 7; i >= 0; i--) {
		int k = decimal >> i;

		if (k & 1) {
			binary.append("1");
		} else {
			binary.append("0");
		}
	}

	return binary;
}

std::string generate_checksum(unsigned char *bytes, size_t size, int bits) {
	sha256_t sha256;
	unsigned char hash[32];

	sha256_init(&sha256);
	sha256_update(&sha256, bytes, size);
	sha256_final(&sha256, hash);

	// Take 1 bit for each 32 bits of the hash
	// hash[0] is 8 bits so we can substr from this value
	// 128 bit hash = 4(128/32) bits checksum
	// 256 bit hash = 8(256/32) bits checksum
	return decimal_to_binary(hash[0]).substr(0, bits / 32);
}

std::vector<int> fingerprint_to_decimals(std::string fingerprint, size_t size) {
 	std::vector<int> decimals;
	int wordSize = 11; // in bits

	// fingerprint = entropy(128 bit) + checksum(4 bit) = 132 bit = 132 / 11 = 12 words
	// fingerprint = entropy(256 bit) + checksum(8 bit) = 264 bit = 264 / 11 = 24 words
	for (int i = 0; i < (size / wordSize); i++) {
		int decimal = binary_to_decimal(fingerprint.substr(i * wordSize, wordSize));

		decimals.push_back(decimal);
	}

	return decimals;
}

// https://www.geeksforgeeks.org/program-binary-decimal-conversion/
int binary_to_decimal(std::string binary) {
	int decimal = 0;

	for (int i = 0; i < binary.size(); i++) {
		decimal <<= 1;

		if (binary[i] == '1') {
			decimal += 1;
		}
	}

	return decimal;
}

std::string decimals_to_words(std::vector<int> decimals, size_t size) {
	std::string words;

	for (int i = 0; i < size; i++) {
    	words.append(BIP39_WORDLIST_ENGLISH[decimals[i]]);

		if (i != size - 1) {
			words.append(" ");
		}
   	}

   	return words;
}

std::string generate_mnemonic(int bits) {
	if (bits != 128 && bits != 256) {
		return std::string("<Invalid amount of bits>");
	}

	unsigned char bytes[16];
	size_t bytes_size = 16;

	generate_random_bytes(bytes, bytes_size);

	std::string entropy = bytes_to_entropy(bytes, bits / 8);
	std::string checksum = generate_checksum(bytes, bits / 8, bits);
	std::string fingerprint;

	fingerprint.append(entropy);
	fingerprint.append(checksum);

	std::vector<int> decimals = fingerprint_to_decimals(fingerprint, fingerprint.size());
	std::string mnemonic = decimals_to_words(decimals, decimals.size());

//	std::cout << entropy << std::endl;
//	std::cout << checksum << std::endl;
//	std::cout << mnemonic << std::endl;
//	std::cout << mnemonic_to_wallet_address(mnemonic) << std::endl;
//	std::cout << mnemonic_to_public_key(mnemonic) << std::endl;

	return mnemonic;
}

std::string mnemonic_to_wallet_address(std::string mnemonic, const int network) {
	sha256_t sha256;
	unsigned char hash[32];

	sha256_init(&sha256);
	sha256_update(&sha256, mnemonic.c_str(), mnemonic.size());
	sha256_final(&sha256, hash);

	wei_curve_t *ec = wei_curve_create(WEI_CURVE_SECP256K1);
	unsigned char publicKeyBytes[33];

	ecdsa_pubkey_create(ec, publicKeyBytes, NULL, hash, 1);

	unsigned char publicKeyHash[20];

	bcl::Ripemd160::getHash(publicKeyBytes, 33, publicKeyHash);

	char address[36];

	bcl::Base58Check::pubkeyHashToBase58Check(publicKeyHash, network, &address[0]);
	wei_curve_destroy(ec);

	return std::string(address);
}

void mnemonic_to_public_key_bytes(std::string mnemonic, unsigned char *bytes) {
	sha256_t sha256;
	unsigned char hash[32];

	sha256_init(&sha256);
	sha256_update(&sha256, mnemonic.c_str(), mnemonic.size());
	sha256_final(&sha256, hash);

	wei_curve_t *ec = wei_curve_create(WEI_CURVE_SECP256K1);

	ecdsa_pubkey_create(ec, bytes, NULL, hash, 1);
	wei_curve_destroy(ec);
}

std::string mnemonic_to_public_key(std::string mnemonic) {
	unsigned char publicKeyBytes[33];

	mnemonic_to_public_key_bytes(mnemonic, publicKeyBytes);

  	char publicKey[67];
  	size_t publicKeySize = 66;

   	base16_encode(publicKey, &publicKeySize, publicKeyBytes, 33);

	return std::string(publicKey);
}

void mnemonic_to_private_key(std::string mnemonic, unsigned char *bytes) {
	sha256_t sha256;

	sha256_init(&sha256);
	sha256_update(&sha256, mnemonic.c_str(), mnemonic.size());
	sha256_final(&sha256, bytes);
}

std::string sign_message(std::string message, std::string mnemonic) {
	sha256_t sha256;
	unsigned char hash[32];

	sha256_init(&sha256);
	sha256_update(&sha256, message.c_str(), message.size());
	sha256_final(&sha256, hash);

	unsigned char signatureBytes[64];
	unsigned char entropy[32];

	torsion_getentropy(entropy, 32);

	wei_curve_t *ec = wei_curve_create(WEI_CURVE_SECP256K1);

	unsigned char privateKeyBytes[32];

	mnemonic_to_private_key(mnemonic, privateKeyBytes);
	bip340_sign(ec, signatureBytes, hash, 32, privateKeyBytes, entropy);

  	char signature[129];
  	size_t signatureSize = 128;

	base16_encode(signature, &signatureSize, signatureBytes, 64);
	wei_curve_destroy(ec);

	return std::string(signature);
}

// Creates a buffer without the signature.
std::vector<uint8_t> create_transfer_transaction_buffer(std::string recipientId, std::string amount, std::string nonce, std::string mnemonic, std::string memo, std::string fee, const int network) {
	const int DEFAULT_TRANSACTION_SIZE = 512;
	std::vector<uint8_t> buffer;

	buffer.resize(DEFAULT_TRANSACTION_SIZE);

	const int HEADER_TYPE_OFFSET = 0;
	const int VERSION_OFFSET = 1;
	const int NETWORK_OFFSET = 2;
	const int TYPE_GROUP_OFFSET = 3;
	const int TYPE_OFFSET = 7;
	const int NONCE_OFFSET = 9;
	const int SENDER_PUBLIC_KEY_OFFSET = 17;
	const int FEE_OFFSET = 50;
	const int MEMO_LENGTH_OFFSET = 58;
	const int MEMO_OFFSET = 59;
	const uint8_t HEADER_TYPE = 0;
	const uint8_t VERSION = 3;
	const uint32_t TYPE_GROUP = 1;
	const uint16_t TYPE = 6;

	buffer.at(HEADER_TYPE_OFFSET) = 255 - HEADER_TYPE; // 1 byte
	buffer.at(VERSION_OFFSET) = VERSION; // 1 byte
	buffer.at(NETWORK_OFFSET) = network; // 1 byte

	memcpy (&buffer.at(TYPE_GROUP_OFFSET), &TYPE_GROUP, sizeof(TYPE_GROUP)); // 4 bytes
	memcpy (&buffer.at(TYPE_OFFSET), &TYPE, sizeof(TYPE)); // 2 bytes

	const uint64_t nonce2 = atoi(nonce.c_str());

	memcpy (&buffer.at(NONCE_OFFSET), &nonce2, sizeof(nonce2)); // 8 bytes

	std::vector<unsigned char> senderPublicKeyBytes;

	senderPublicKeyBytes.resize(33);
	mnemonic_to_public_key_bytes(mnemonic, &senderPublicKeyBytes[0]);
	buffer.insert(buffer.begin() + SENDER_PUBLIC_KEY_OFFSET, senderPublicKeyBytes.begin(), senderPublicKeyBytes.end()); // 21 bytes

	uint64_t fee2 = atoi(fee.c_str());

	memcpy (&buffer.at(FEE_OFFSET), &fee2, sizeof(fee2)); // 8 bytes

	buffer.at(MEMO_LENGTH_OFFSET) = memo.size(); // 1 byte

	if (!memo.empty()) {
		buffer.insert(buffer.begin() + MEMO_OFFSET, memo.begin(), memo.end()); // 0 - 255 bytes
	}

	const int assetOffset = MEMO_OFFSET + memo.size();

	std::vector<uint8_t> asset;

	const uint16_t amountOfTransfers = 1;
	const int AMOUNT_OF_TRANSFERS_SIZE = 2;
	const int TRANSFER_SIZE = 8 + 21; // Transfer amount 8 bytes + transfer recipientId 21 bytes

	asset.resize(AMOUNT_OF_TRANSFERS_SIZE + amountOfTransfers * TRANSFER_SIZE);
	memcpy (&asset.at(0), &amountOfTransfers, sizeof(amountOfTransfers)); // 2 bytes

	const int TRANSFER_AMOUNT_OFFSET = 2;
	const int TRANSFER_NETWORK_VERSION_OFFSET = 10;
	const int TRANSFER_RECIPIENT_ID_OFFSET = 11;

	uint64_t amount2 = atoi(amount.c_str());

	memcpy (&asset.at(TRANSFER_AMOUNT_OFFSET), &amount2, sizeof(amount2)); // 8 bytes

	std::vector<unsigned char> publicKeyHash;
	uint8_t network2 = network;

	publicKeyHash.resize(20);
	bcl::Base58Check::pubkeyHashFromBase58Check(recipientId.c_str(), &publicKeyHash[0], &network2);

	asset.at(TRANSFER_NETWORK_VERSION_OFFSET) = network; // 1 byte

	memcpy (&asset.at(TRANSFER_RECIPIENT_ID_OFFSET), &publicKeyHash[0], publicKeyHash.size()); // 21 bytes
	buffer.insert(buffer.begin() + assetOffset, asset.begin(), asset.end());
	buffer.resize(assetOffset + asset.size());

	return buffer;
}

// Make sure that the buffer does NOT include the signature.
void create_transfer_transaction_hash(std::vector<uint8_t> buffer, unsigned char *bytes) {
	sha256_t sha256;

	sha256_init(&sha256);
	sha256_update(&sha256, &buffer[0], buffer.size());
	sha256_final(&sha256, bytes);
}

std::vector<uint8_t> create_transfer_transaction_signature_buffer(std::vector<uint8_t> buffer, std::string mnemonic) {
	unsigned char hash[32];

	create_transfer_transaction_hash(buffer, hash);

	std::vector<unsigned char> signatureBytes;

	signatureBytes.resize(64);

	unsigned char entropy[32];

	torsion_getentropy(entropy, 32);

	wei_curve_t *ec = wei_curve_create(WEI_CURVE_SECP256K1);

	unsigned char privateKeyBytes[32];

	mnemonic_to_private_key(mnemonic, privateKeyBytes);
	bip340_sign(ec, &signatureBytes[0], hash, 32, privateKeyBytes, entropy);
	wei_curve_destroy(ec);

	return signatureBytes;
}

std::string create_transfer_transaction_signature(std::vector<uint8_t> buffer) {
	char signature[129];
	size_t signatureSize = 128;

	base16_encode(signature, &signatureSize, &buffer[0], 64);

	return std::string(signature);
}

// The transaction buffer (without signature) and the signature buffer require to be merged in order to generate
// a transaction ID.
std::string create_transfer_transaction_id(std::vector<uint8_t> buffer, std::vector<uint8_t> signatureBuffer) {
	const int signatureOffset = buffer.size();
	const int DEFAULT_TRANSACTION_SIZE = 512;

	// Resize the buffer to make room for the signature bytes.
	buffer.resize(DEFAULT_TRANSACTION_SIZE);
	buffer.insert(buffer.begin() + signatureOffset, signatureBuffer.begin(), signatureBuffer.end()); // 64 bytes
	buffer.resize(signatureOffset + signatureBuffer.size());

	unsigned char hash[32];

	create_transfer_transaction_hash(buffer, hash);

	char transactionIdBytes[65];
	size_t transactionIdSize = 64;

	base16_encode(transactionIdBytes, &transactionIdSize, &hash[0], 32);

	return std::string(transactionIdBytes);
}
