{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  rocksdb,
  testers,
  protobuf,
  withRocksDB ? false,
}:
let
  cargoBuildFeatures = [
    "allocator"
    "allocation-tracking"
    "http"
    "scripting"
    "storage-mem"
    "storage-surrealcs"
    "storage-surrealkv"
  ]
  ++ lib.optional withRocksDB "storage-rocksdb";
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = if withRocksDB then "surrealdb-rocksdb" else "surrealdb";
  version = "2.6.1";

  src = fetchFromGitHub {
    owner = "surrealdb";
    repo = "surrealdb";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Dd6tabpSTh7IN9PLE4Zt/s1G7mNUwYfy+nEZpPTy8a8=";
  };

  cargoHash = "sha256-lebSQPGnxW+3a7vWw3R7QYtHx04/DsRK/n8c/UT3FZo=";

  # error: linker `aarch64-linux-gnu-gcc` not found
  postPatch = ''
    rm .cargo/config.toml
  '';

  buildNoDefaultFeatures = true;
  buildFeatures = cargoBuildFeatures;

  env = {
    PROTOC = "${protobuf}/bin/protoc";
    PROTOC_INCLUDE = "${protobuf}/include";
    RUSTFLAGS = "--cfg surrealdb_unstable";
  }
  // lib.optionalAttrs withRocksDB {
    ROCKSDB_INCLUDE_DIR = "${rocksdb}/include";
    ROCKSDB_LIB_DIR = "${rocksdb}/lib";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    openssl
  ];

  doCheck = false;

  checkFlags = [
    # requires docker
    "--skip=database_upgrade"
  ];

  __darwinAllowLocalNetworking = true;
  __structuredAttrs = true;

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "surreal version";
  };

  meta = {
    description = "Scalable, distributed, collaborative, document-graph database, for the realtime web";
    homepage = "https://surrealdb.com/";
    mainProgram = "surreal";
    license = lib.licenses.bsl11;
    maintainers = with lib.maintainers; [
      sikmir
      happysalada
      siriobalmelli
    ];
  };
})
