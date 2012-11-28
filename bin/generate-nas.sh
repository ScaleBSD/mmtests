#!/bin/bash
# generate-speccpu.sh - Generate SPECcpu configuration file
#
# Does what it says on the tin, generates a SPEC configuration file using
# gcc as a compiler. It can also be used to auto-generate some informationo
# about the machine itself

# Exit codes
EXIT_SUCCESS=0
EXIT_FAILURE=-1

# Default
GCC_VERSION=
GCC_OPTIMIZE="-O2"
BITNESS=32
ARCH=`uname -m`
HUGEPAGES="no"
OPENMP=

##
# usage - Print usage
usage() {
	echo "
generate-nas.sh (c) Mel Gorman 2009

Usage: generate-nas.sh [options]
  -h, --help   Print this usage message
  --gcc        GCC version (Default: installed)
  --conf file  Read default configuration values from file
  --bitness    32/64 bitness (Default: $BITNESS)
  --openmp     Enable use of OpenMP
  --openmpi    Enable use of OpenMPI
  --hugepages-heaponly   Use hugepages in the configuration
  --hugepages-oldrelink  Use hugepages in the configuration
  --hugepages-newrelink  Use hugepages in the configuration
"
	exit $1
}

##
# warning - Print a warning
# die - Exit with error message
warning() {
	echo "WARNING: $@"
}

die() {
	echo "FATAL: $@"
	exit $EXIT_FAILURE
}

##
# emit_header - Emit header
emit_header() {
	echo "# Autogenerated by generate-nas.sh"
	echo
}

##
# emit_compiler - Print the compiler configuration
emit_compiler() {
	if [ "$OPENMPI" != "" ]; then
		COMPILE_FORTRAN=mpif77
		COMPILE_C=mpicc

		echo "## Compiler"
		echo "MPIF77             = $COMPILE_FORTRAN"
		echo "MPICC              = $COMPILE_C"
		echo
	else
		if [ "$GCC_VERSION" != "" ]; then
			COMPILE_FORTRAN="gfortran-$GCC_VERSION"
			COMPILE_C="gcc-$GCC_VERSION"
		else
			COMPILE_FORTRAN="gfortran"
			COMPILE_C="gcc"
		fi

		echo "## Compiler"
		echo "F77                = $COMPILE_FORTRAN"
		echo "CC                 = $COMPILE_C"
		echo
	fi

	# Belated check but who cares, it'll still work
	if [ "`which $COMPILE_FORTRAN`" = "" ]; then die No $COMPILE_FORTRAN; fi
	if [ "`which $COMPILE_C`" = "" ]; then die No $COMPILE_C; fi
}

##
# emit_optimization - Emit compiler optimizations and notes
emit_optimization() {
	echo "# libhugetlbfs relinking"
	echo "LHBDT = -B /usr/share/libhugetlbfs -Wl,--hugetlbfs-link=BDT"
	echo "LHB = -B /usr/share/libhugetlbfs -Wl,--hugetlbfs-link=B"
	echo "LHALIGN = -B /usr/share/libhugetlbfs -Wl,--hugetlbfs-align"
	LIBHUGEPATH=
	if [ -e /usr/lib/x86_64-linux-gnu/ ]; then
		LIBHUGEPATH=-L/usr/lib/x86_64-linux-gnu/
	fi

	if [ "$HUGEPAGES" = "old-relink" ]; then
		echo "LHRELINK = \$(LHBDT)"
		echo "LHLIB = $LIBHUGEPATH -lhugetlbfs"
	fi
	if [ "$HUGEPAGES" = "new-relink" ]; then
		echo "LHRELINK = \$(LHALIGN)"
		echo "LHLIB = $LIBHUGEPATH -lhugetlbfs"
	fi
	if [ "$HUGEPAGES" = "heaponly" ]; then
		echo "LHRELINK = "
		echo "LHLIB = $LIBHUGEPATH -lhugetlbfs"
	fi

	EFLAGS=
	if [ "`uname -m`" = "x86_64" ]; then
		case $NAS_CLASS in
		C)
			EFLAGS=-mcmodel=medium
			;;
		D)
			EFLAGS=-mcmodel=large
			;;
		E)
			EFLAGS=-mcmodel=large
			;;
		F)
			EFLAGS=-mcmodel=large
			;;
		esac
	fi

	echo
	echo "# Fortran Optimisation"
	echo "FLINK              = $COMPILE_FORTRAN"
	echo "F_LIB              = \$(LHRELINK) \$(LHLIB)"
	echo "F_INC              ="
	echo "FFLAGS             = $GCC_OPTIMIZE $OPENMP $EFLAGS -m$BITNESS"
	echo "FLINKFLAGS         = $GCC_OPTIMIZE $OPENMP $EFLAGS -m$BITNESS \$(LHRELINK) \$(LHLIB)"

	echo
	echo "# C Optimisation"
	echo "CLINK              = $COMPILE_C"
	echo "C_LIB              = \$(LHRELINK) \$(LHLIB)"
	echo "C_INC              ="
	echo "CFLAGS             = $GCC_OPTIMIZE $OPENMP $EFLAGS -m$BITNESS"
	echo "CLINKFLAGS         = $GCC_OPTIMIZE $OPENMP $OPENMPI $EFLAGS -m$BITNESS \$(LHRELINK) \$(LHLIB)"

	echo
	echo "# Other"
	echo "UCC                = $COMPILE_C"
	echo "BINDIR             = ../bin"
	echo "RAND               = randi8"
	echo "WTIME              = wtime.c"
}

##
# emit_footer - Print the end
emit_footer() {
	echo
}

# Parse the arguments
OPTARGS=`getopt -o h --long help,gcc,emit-conf,bitness:,conf:,monitor:,hugepages-heaponly,hugepages-oldrelink,hugepages-newrelink,openmp,openmpi -n generate-speccpu.sh -- "$@"`
eval set -- "$OPTARGS"
while [ "$1" != "" ] && [ "$1" != "--" ]; do
	case "$1" in
		-h|--help)
			usage $EXIT_SUCCESS;
			;;
		--gcc)
			GCC_VERSION=$2
			shift 2
			;;
		--bitness)
			BITNESS=$2
			shift 2
			;;
		--hugepages-heaponly)
			HUGEPAGES=heaponly
			shift
			;;
		--hugepages-oldrelink)
			HUGEPAGES=old-relink
			shift
			;;
		--hugepages-newrelink)
			HUGEPAGES=new-relink
			shift
			;;
		--openmp)
			OPENMP=-fopenmp
			OPENMPI=
			shift
			;;
		--openmpi)
			OPENMPI=-lmpi
			OPENMP=
			shift
			;;

	esac
done

# Generate a spec file
emit_header
emit_compiler
emit_optimization
emit_footer