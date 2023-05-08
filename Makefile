# Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Original Author: Shay Gal-on

# 确保默认目标是只需构建和运行基准测试。
RSTAMP = v1.0

.PHONY: run score
run: $(OUTFILE) rerun score

score:
	@echo "请参阅 README.md 以获取运行和报告规则。"
	@echo "请检查 run1.log 和 run2.log 查看结果。"

# 定义一个 PORT_DIR 变量，其默认值为系统的类型。
ifndef PORT_DIR
# 自定义主机平台的端口
UNAME=$(shell if command -v uname 2> /dev/null; then uname ; fi)
ifneq (,$(findstring CYGWIN,$(UNAME)))
PORT_DIR=cygwin
endif
ifneq (,$(findstring Darwin,$(UNAME)))
PORT_DIR=macos
endif
ifneq (,$(findstring FreeBSD,$(UNAME)))
PORT_DIR=freebsd
endif
ifneq (,$(findstring Linux,$(UNAME)))
PORT_DIR=linux
endif
endif
ifndef PORT_DIR
$(error PLEASE define PORT_DIR! (e.g. make PORT_DIR=simple))
endif

# 设置程序头文件，源文件和对象文件的路径
vpath %.c $(PORT_DIR)
vpath %.h $(PORT_DIR)
vpath %.mak $(PORT_DIR)

# 包括核心主机程序
include $(PORT_DIR)/core_portme.mak

# 初始化 ITERATIONS 和 REBUILD 变量
ifndef ITERATIONS
ITERATIONS=0
endif
ifdef REBUILD
FORCE_REBUILD=force_rebuild
endif

# 往编译选项中增加宏参数：ITERATIONS
CFLAGS += -DITERATIONS=$(ITERATIONS)

CORE_FILES = core_list_join core_main core_matrix core_state core_util
ORIG_SRCS = $(addsuffix .c,$(CORE_FILES))
SRCS = $(ORIG_SRCS) $(PORT_SRCS)
OBJS = $(addprefix $(OPATH),$(addsuffix $(OEXT),$(CORE_FILES)) $(PORT_OBJS))
OUTNAME = coremark$(EXE)
OUTFILE = $(OPATH)$(OUTNAME)
LOUTCMD = $(OFLAG) $(OUTFILE) $(LFLAGS_END)
OUTCMD = $(OUTFLAG) $(OUTFILE) $(LFLAGS_END)

HEADERS = coremark.h
CHECK_FILES = $(ORIG_SRCS) $(HEADERS)

# 检查目录是否存在，不存在就创建它
$(OPATH):
	$(MKDIR) $(OPATH)

.PHONY: compile link
# 合并进行编译和链接
compile: $(OPATH) $(SRCS) $(HEADERS)
	$(CC) $(CFLAGS) $(XCFLAGS) $(SRCS) $(OUTCMD)
link: compile
	@echo "链接同时进行编译"

# 生成可执行文件
$(OUTFILE): $(SRCS) $(HEADERS) Makefile core_portme.mak $(EXTRA_DEPENDS) $(FORCE_REBUILD)
	$(MAKE) port_prebuild
	$(MAKE) link
	$(MAKE) port_postbuild

.PHONY: rerun
rerun:
	$(MAKE) XCFLAGS="$(XCFLAGS) -DPERFORMANCE_RUN=1" load run1.log
	$(MAKE) XCFLAGS="$(XCFLAGS) -DVALIDATION_RUN=1" load run2.log

# 定义了三个运行 log 文件的依赖，全部依赖 load 命令
PARAM1=$(PORT_PARAMS) 0x0 0x0 0x66 $(ITERATIONS)
PARAM2=$(PORT_PARAMS) 0x3415 0x3415 0x66 $(ITERATIONS)
PARAM3=$(PORT_PARAMS) 8 8 8 $(ITERATIONS)

run1.log-PARAM=$(PARAM1) 7 1 2000
run2.log-PARAM=$(PARAM2) 7 1 2000
run3.log-PARAM=$(PARAM3) 7 1 1200

run1.log run2.log run3.log: load
	$(MAKE) port_prerun
	$(RUN) $(OUTFILE) $($(@)-PARAM) > $(OPATH)$@
	$(MAKE) port_postrun

# 生成 PGO 数据
.PHONY: gen_pgo_data
gen_pgo_data: run3.log

.PHONY: load
load: $(OUTFILE)
	$(MAKE) port_preload
	$(LOAD) $(OUTFILE)
	$(MAKE) port_postload

# 清理命令，删除所有的生成文件
.PHONY: clean
clean:
	rm -f $(OUTFILE) $(OBJS) $(OPATH)*.log *.info $(OPATH)index.html $(PORT_CLEAN)

.PHONY: force_rebuild
force_rebuild:
	echo "强制重建"

# 校验一下 MD5
.PHONY: check
check:
	md5sum -c coremark.md5

ifdef ETC
# 这部分目标旨在测试和发布 CoreMark。不是正式发布的一部分！

# 引入内部 Makefile。
include Makefile.internal
endif
