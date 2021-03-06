"""
    @sync ex

Run expression `ex` and synchronize the GPU afterwards. This is a CPU-friendly
synchronization, i.e. it performs a blocking synchronization without increasing CPU load. As
such, this operation is preferred over implicit synchronization (e.g. when performing a
memory copy) for high-performance applications.

It is also useful for timing code that executes asynchronously.
"""
macro sync(ex)
    quote
        local e = CuEvent(EVENT_BLOCKING_SYNC | EVENT_DISABLE_TIMING)
        local ret = $(esc(ex))
        record(e)
        synchronize(e)
        ret
    end
end

function versioninfo(io::IO=stdout)
    println(io, "CUDA toolkit $(toolkit_version()), $(toolkit_origin()) installation")
    println(io, "CUDA driver $(release())")
    if has_nvml()
        println(io, "NVIDIA driver $(NVML.driver_version())")
    end
    println(io)

    println(io, "Libraries: ")
    for lib in (:CUBLAS, :CURAND, :CUFFT, :CUSOLVER, :CUSPARSE)
        mod = getfield(CUDA, lib)
        println(io, "- $lib: ", mod.version())
    end
    println(io, "- CUPTI: ", has_cupti() ? CUPTI.version() : "missing")
    println(io, "- NVML: ", has_nvml() ? NVML.version() : "missing")
    println(io, "- CUDNN: ", has_cudnn() ? "$(CUDNN.version()) (for CUDA $(CUDNN.cuda_version()))" : "missing")
    println(io, "- CUTENSOR: ", has_cutensor() ? "$(CUTENSOR.version()) (for CUDA $(CUTENSOR.cuda_version()))" : "missing")
    println(io)

    println(io, "Toolchain:")
    println(io, "- Julia: $VERSION")
    println(io, "- LLVM: $(LLVM.version())")
    println(io, "- PTX ISA support: $(join(map(ver->"$(ver.major).$(ver.minor)", __ptx_support[]), ", "))")
    println(io, "- Device support: $(join(map(ver->"sm_$(ver.major)$(ver.minor)", __target_support[]), ", "))")
    println(io)

    env = filter(var->startswith(var, "JULIA_CUDA"), keys(ENV))
    if !isempty(env)
        println(io, "Environment:")
        for var in env
            println(io, "- $var: $(ENV[var])")
        end
        println(io)
    end

    if has_nvml()
        devs = NVML.devices()
        println(io, length(devs), " device(s):")
        for dev in devs
            cap = NVML.compute_capability(dev)
            mem = NVML.memory_info(dev)
            name = NVML.name(dev)
            println(io, "- $name (sm_$(cap.major)$(cap.minor), $(Base.format_bytes(mem.free)) / $(Base.format_bytes(mem.total)) available)")
        end
    else
        devs = devices()
        println(io, length(devs), " device(s):")
        for dev in devs
            cap = capability(dev)
            device!(dev) do
                println(io, "- $(name(dev)) (sm_$(cap.major)$(cap.minor), $(Base.format_bytes(available_memory())) / $(Base.format_bytes(total_memory())) available)")
            end
        end
    end
end
