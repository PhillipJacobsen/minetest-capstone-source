set(SOLAR_CRYPTO_SRC
	solar/lib/libtorsion/src/aead.c
	solar/lib/libtorsion/src/asn1.c
	solar/lib/libtorsion/src/cipher.c
	solar/lib/libtorsion/src/ecc.c
	solar/lib/libtorsion/src/encoding.c
	solar/lib/libtorsion/src/drbg.c
	solar/lib/libtorsion/src/dsa.c
	solar/lib/libtorsion/src/hash.c
	solar/lib/libtorsion/src/ies.c
	solar/lib/libtorsion/src/internal.c
	solar/lib/libtorsion/src/kdf.c
	solar/lib/libtorsion/src/mac.c
	solar/lib/libtorsion/src/mpi.c
	solar/lib/libtorsion/src/rsa.c
	solar/lib/libtorsion/src/stream.c
	solar/lib/libtorsion/src/util.c
	solar/lib/libtorsion/src/entropy/hw.c
	solar/lib/libtorsion/src/entropy/sys.c
	solar/lib/libtorsion/src/rand.c
	solar/lib/bcl/src/Base58Check.cpp
    solar/lib/bcl/src/CurvePoint.cpp
    solar/lib/bcl/src/Ecdsa.cpp
    solar/lib/bcl/src/ExtendedPrivateKey.cpp
    solar/lib/bcl/src/FieldInt.cpp
    solar/lib/bcl/src/Keccak256.cpp
    solar/lib/bcl/src/Ripemd160.cpp
    solar/lib/bcl/src/Sha256.cpp
    solar/lib/bcl/src/Sha256Hash.cpp
    solar/lib/bcl/src/Sha512.cpp
    solar/lib/bcl/src/Uint256.cpp
    solar/lib/bcl/src/Utils.cpp
	main.c
)

add_library(solar_crypto STATIC ${SOLAR_CRYPTO_SRC})
target_link_libraries(solar_crypto ${LIBS})

set_source_files_properties(${SOLAR_CRYPTO_SRC} PROPERTIES LANGUAGE CXX)
