{
  lib,
  torch,
  buildPythonPackage,
  fetchFromGitHub,

  # nativeBuildInputs
  libpng,
  ninja,
  which,

  # buildInputs
  libjpeg_turbo,

  # dependencies
  numpy,
  pillow,
  scipy,

  # tests
  pytest,
  writableTmpDirAsHomeHook,

  cudaSupport ? torch.cudaSupport,
  cudaPackages,
  rocmSupport ? torch.rocmSupport,
  rocmPackages,
}:

buildPythonPackage.override { stdenv = torch.stdenv; } (finalAttrs: {
  pname = "torchvision";
  version = "0.25.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "pytorch";
    repo = "vision";
    tag = "v${finalAttrs.version}";
    hash = "sha256-oktJHcT6T4f58pUO+HSBpbyS1ISH3zDlTsXQh6PcMy4=";
  };

  nativeBuildInputs =
    [
      libpng
      ninja
      which
    ]
    ++ lib.optionals cudaSupport [ cudaPackages.cuda_nvcc ]
    ++ lib.optionals rocmSupport [ rocmPackages.clr ];

  buildInputs = [
    libjpeg_turbo
    libpng
    torch.cxxdev
  ];

  dependencies = [
    numpy
    pillow
    torch
    scipy
  ];

  env =
    {
      TORCHVISION_INCLUDE = "${libjpeg_turbo.dev}/include/";
      TORCHVISION_LIBRARY = "${libjpeg_turbo}/lib/";
    }
    // lib.optionalAttrs cudaSupport {
      TORCH_CUDA_ARCH_LIST = "${lib.concatStringsSep ";" torch.cudaCapabilities}";
      FORCE_CUDA = "1";
    }
    // lib.optionalAttrs rocmSupport {
      # FORCE_CUDA makes setup.py compile GPU kernels without requiring a
      # visible GPU (absent in the sandbox).  IS_ROCM is detected separately
      # via torch.version.hip + ROCM_HOME and steers hipify instead of nvcc.
      FORCE_CUDA = "1";
      ROCM_PATH = "${torch.rocmtoolkit_joined}";
      ROCM_HOME = "${torch.rocmtoolkit_joined}";
      PYTORCH_ROCM_ARCH = torch.gpuTargetString;
      # hipcc bypasses the nix compiler wrapper, so headers from buildInputs
      # are invisible.  CPLUS_INCLUDE_PATH is honoured by the underlying clang.
      CPLUS_INCLUDE_PATH = lib.makeSearchPath "include" (
        with rocmPackages; [
          clr
          rocthrust
          rocprim
          hipsparse
          hipblas
          hipblas-common
          hipblaslt
          rocsparse
          rocblas
          rocsolver
          hipsolver
          hipfft
          rocfft
          miopen
          rccl
          rocm-core
          rocm-runtime
          rocm-comgr
          rocm-device-libs
          rocrand
          roctracer
        ]
      );
    };

  # tests download big datasets, models, require internet connection, etc.
  doCheck = false;

  pythonImportsCheck = [ "torchvision" ];

  nativeCheckInputs = [
    pytest
    writableTmpDirAsHomeHook
  ];

  checkPhase = ''
    py.test test --ignore=test/test_datasets_download.py
  '';

  meta = {
    description = "PyTorch vision library";
    homepage = "https://pytorch.org/";
    changelog = "https://github.com/pytorch/vision/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.bsd3;
    platforms =
      lib.platforms.linux ++ lib.optionals (!cudaSupport && !rocmSupport) lib.platforms.darwin;
    maintainers = with lib.maintainers; [ GaetanLepage caniko ];
  };
})
