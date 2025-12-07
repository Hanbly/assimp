-- 获取当前 premake5.lua 所在的绝对目录
local current_dir = path.getdirectory(_SCRIPT)
-- 动态拼接 include 目录，彻底杜绝路径错误
local assimp_include_dir = path.join(current_dir, "include/assimp")

project "Assimp"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "off"
    warnings "off"

    targetdir ("bin/" .. outputdir .. "/%{prj.name}")
    objdir ("bin-int/" .. outputdir .. "/%{prj.name}")

    ---------------------------------------------------------------------------
    -- 自动化脚本：基于绝对路径生成 config.h / revision.h
    ---------------------------------------------------------------------------
    local function generate_assimp_headers()
        print("Generating Assimp config headers in: " .. assimp_include_dir)

        -- 定义源文件 (.in) 和 目标文件 (.h) 的绝对路径
        local config_in  = path.join(assimp_include_dir, "config.h.in")
        local config_out = path.join(assimp_include_dir, "config.h")
        local rev_in     = path.join(assimp_include_dir, "revision.h.in")
        local rev_out    = path.join(assimp_include_dir, "revision.h")

        -- 1. 处理 config.h
        local f = io.open(config_in, "r")
        if f then
            local content = f:read("*all")
            f:close()

            -- 替换 CMake 宏
            content = content:gsub("#cmakedefine%s+([%w_]+)%s+(.+)", "#define %1 %2")
            content = content:gsub("#cmakedefine%s+([%w_]+)", "#define %1 1")
            
            -- 替换特定变量
            content = content:gsub("@ASSIMP_DOUBLE_PRECISION@", "0") 
            content = content:gsub("@ASSIMP_BUILD_NO_OWN_ZLIB@", "0")
            content = content:gsub("@ASSIMP_VERSION_MAJOR@", "5")
            content = content:gsub("@ASSIMP_VERSION_MINOR@", "2")
            content = content:gsub("@ASSIMP_VERSION_PATCH@", "5")

            -- [关键] 清理所有剩余的 @VAR@ 格式，防止 0x40 错误
            content = content:gsub("@[%w_]+@", "0") 

            local out = io.open(config_out, "w")
            if out then out:write(content); out:close() end
            print("  [OK] Generated: config.h")
        else
            print("  [Error] Cannot find: " .. config_in)
        end

        -- 2. 处理 revision.h
        local f_rev = io.open(rev_in, "r")
        if f_rev then
            local content = f_rev:read("*all")
            f_rev:close()
            
            -- 替换 git 信息
            content = content:gsub("@git_commit_hash@", "0")
            content = content:gsub("@git_branch@", "master")
            -- 清理剩余 @
            content = content:gsub("@[%w_]+@", "0")

            local out_rev = io.open(rev_out, "w")
            if out_rev then out_rev:write(content); out_rev:close() end
            print("  [OK] Generated: revision.h")
        else
            -- 如果找不到 .in 文件，强制写入一个最小化版本
            print("  [Warning] revision.h.in not found, creating default.")
            local content = "#ifndef ASSIMP_REVISION_H_INC\n#define ASSIMP_REVISION_H_INC\n#define GitVersion 0x0\n#define GitBranch \"master\"\n#endif\n"
            local out_rev = io.open(rev_out, "w")
            if out_rev then out_rev:write(content); out_rev:close() end
        end
    end

    generate_assimp_headers()
    ---------------------------------------------------------------------------

    files {
        "code/**.cpp",
        "code/**.h",
        "include/**.h",
        "include/**.hpp",
        "include/**.inl",
        
        "contrib/zlib/*.c", "contrib/zlib/*.h",
        "contrib/irrXML/*.cpp", "contrib/irrXML/*.h",
        "contrib/unzip/*.c", "contrib/unzip/*.h",
        "contrib/poly2tri/poly2tri/**.cpp", "contrib/poly2tri/poly2tri/**.h",
        "contrib/clipper/*.cpp", "contrib/clipper/*.h",
        "contrib/pugixml/src/*.cpp", "contrib/pugixml/src/*.hpp",
        "contrib/openddlparser/code/*.cpp", "contrib/openddlparser/include/**.h"
    }

    removefiles {
        "code/Tests/**",
        "test/**"
    }

    includedirs {
        "include",
        "code",
        ".",
        "code/Common", 
        "contrib/zlib",
        "contrib/irrXML",
        "contrib/unzip",
        "contrib/rapidjson/include",
        "contrib/pugixml/src",
        "contrib/utf8cpp/source",
        "contrib/openddlparser/include",
        "contrib"
    }

    defines {
        "_CRT_SECURE_NO_WARNINGS",
        "NOMINMAX",
        "RAPIDJSON_HAS_STDSTRING=1", 
        "RAPIDJSON_NOMEMBERITERATORCLASS", 
        "OPENDDL_STATIC_LIBARY", 
        
        "ASSIMP_BUILD_NO_C4D_IMPORTER", 
        "ASSIMP_BUILD_NO_IFC_IMPORTER",
        "ASSIMP_BUILD_NO_USD_IMPORTER",
        "ASSIMP_BUILD_NO_X3D_IMPORTER",
        "ASSIMP_BUILD_NO_M3D_IMPORTER",
        "ASSIMP_BUILD_NO_M3D_EXPORTER",
        
        "ASSIMP_BUILD_NO_OWN_ZLIB=0"
    }

    -- 屏蔽无用警告
    disablewarnings { 
        "4244", "4305", "4100", "4996", "4018", "4267"
    }

    filter "system:windows"
        systemversion "latest"

    filter "configurations:Debug"
        runtime "Debug"
        symbols "On"

    filter "configurations:Release"
        runtime "Release"
        optimize "On"

    filter "configurations:Dist"
        runtime "Release"
        optimize "On"