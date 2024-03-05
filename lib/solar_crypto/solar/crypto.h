#pragma once

#include <vector>

void generate_random_bytes(unsigned char *bytes, size_t size);
std::string bytes_to_entropy(unsigned char *bytes, size_t size);
std::string decimal_to_binary(int decimal);
std::string generate_checksum(unsigned char *bytes, size_t size, int bits);
std::vector<int> fingerprint_to_decimals(std::string fingerprint, size_t size);
int binary_to_decimal(std::string binary);
std::string decimals_to_words(std::vector<int> decimals, size_t size);
std::string generate_mnemonic(int bits);
std::string mnemonic_to_wallet_address(std::string mnemonic, const int network = 63);
unsigned char mnemonic_to_public_key_bytes(std::string mnemonic);
std::string mnemonic_to_public_key(std::string mnemonic);
std::string mnemonic_to_private_key(std::string mnemonic);
std::string sign_message(std::string message, std::string mnemonic);
std::vector<uint8_t> create_transfer_transaction_buffer(std::string recipientId, std::string amount, std::string nonce, std::string mnemonic, std::string memo, std::string fee, const int network = 63);
void create_transfer_transaction_hash(std::vector<uint8_t> buffer, unsigned char *bytes);
std::vector<uint8_t> create_transfer_transaction_signature_buffer(std::vector<uint8_t> buffer, std::string mnemonic);
std::string create_transfer_transaction_id(std::vector<uint8_t> buffer, std::vector<uint8_t> signatureBuffer);
std::string create_transfer_transaction_signature(std::vector<uint8_t> buffer);
