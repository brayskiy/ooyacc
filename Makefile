SHELL         = /bin/bash 
MKDIR         = mkdir -p
RM            = rm

INSTALL_DIR   = $(HOME)/bin

BIN_DIR       = bin
SRC_DIR       = src
OBJ_DIR       = obj

HDRS	      = defs.h

#CFLAGS	      = -O -DNDEBUG -g
CFLAGS	      = -Wall -O3

LDFLAGS	      =

LIBS	      =

LINKER	      = g++

MAKEFILE      = Makefile

PROGRAM       = ooyacc

OBJS	      = $(OBJ_DIR)/closure.o 	\
		$(OBJ_DIR)/error.o 	\
		$(OBJ_DIR)/lalr.o 	\
		$(OBJ_DIR)/lr0.o 	\
		$(OBJ_DIR)/main.o 	\
		$(OBJ_DIR)/mkpar.o 	\
		$(OBJ_DIR)/output.o 	\
		$(OBJ_DIR)/reader.o 	\
		$(OBJ_DIR)/skeleton.o 	\
		$(OBJ_DIR)/symtab.o 	\
		$(OBJ_DIR)/verbose.o

SRCS	      = ${SRC_DIR}/closure.cpp	\
		${SRC_DIR}/error.cpp 	\
		${SRC_DIR}/lalr.cpp	\
		${SRC_DIR}/lr0.cpp 	\
		${SRC_DIR}/main.cpp	\
		${SRC_DIR}/mkpar.cpp 	\
		${SRC_DIR}/output.cpp 	\
		${SRC_DIR}/reader.cpp 	\
		${SRC_DIR}/skeleton.cpp \
		${SRC_DIR}/symtab.cpp 	\
		${SRC_DIR}/verbose.cpp  \

all: clean directories program install

program: ${PROGRAM}

directories:
	${MKDIR} ${OBJ_DIR}
	${MKDIR} ${BIN_DIR}
	${MKDIR} ${INSTALL_DIR}

${PROGRAM}: $(OBJS)
	@echo -n "Loading $(PROGRAM) ... "
	$(LINKER) $(LDFLAGS) -o $(BIN_DIR)/$(PROGRAM) $(OBJS) $(LIBS)
	@echo "... well done"

clean:
	${RM} -rf ${OBJ_DIR} ${BIN_DIR}

install: directories program
	@echo Installing $(PROGRAM) in $(INSTALL_DIR)
	@install -s ${BIN_DIR}/${PROGRAM} $(INSTALL_DIR)

###
$(OBJ_DIR)/closure.o:  ${SRC_DIR}/closure.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/closure.cpp  $(CFLAGS) -o $@
$(OBJ_DIR)/error.o:    ${SRC_DIR}/error.cpp 
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/error.cpp    $(CFLAGS) -o $@
$(OBJ_DIR)/lalr.o:     ${SRC_DIR}/lalr.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/lalr.cpp     $(CFLAGS) -o $@
$(OBJ_DIR)/lr0.o:      ${SRC_DIR}/lr0.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/lr0.cpp      $(CFLAGS) -o $@
$(OBJ_DIR)/main.o:     ${SRC_DIR}/main.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/main.cpp     $(CFLAGS) -o $@
$(OBJ_DIR)/mkpar.o:    ${SRC_DIR}/mkpar.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/mkpar.cpp    $(CFLAGS) -o $@
$(OBJ_DIR)/output.o:   ${SRC_DIR}/output.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/output.cpp   $(CFLAGS) -o $@
$(OBJ_DIR)/reader.o:   ${SRC_DIR}/reader.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/reader.cpp   $(CFLAGS) -o $@
$(OBJ_DIR)/skeleton.o: ${SRC_DIR}/skeleton.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/skeleton.cpp $(CFLAGS) -o $@
$(OBJ_DIR)/symtab.o:   ${SRC_DIR}/symtab.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/symtab.cpp   $(CFLAGS) -o $@
$(OBJ_DIR)/verbose.o:  ${SRC_DIR}/verbose.cpp
	$(LINKER) $(LDFLAGS) -c ${SRC_DIR}/verbose.cpp  $(CFLAGS) -o $@
