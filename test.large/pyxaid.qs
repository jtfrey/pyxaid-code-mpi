#
# Template:  OpenMPI, Default (OpenIB Infiniband w/ Mellanox Optimizations) Variant
# Revision:  $Id: openmpi-ib-optimized.qs 635 2017-02-08 20:32:14Z frey $
#
# Usage:
# 1. Modify "NPROC" in the -pe line to reflect the number
#    of processors desired.
# 2. Modify the value of "PYXAID_SCRIPT" to be the path to the Python
#    script you wish to run.  Note that the script must use mpi4py for
#    parallelization.
# 3. Uncomment the WANT_CPU_AFFINITY line if you want Open MPI to
#    bind workers to processor cores.  Can increase your program's
#    efficiency.
# 4. Uncomment the SHOW_MPI_DEBUGGING line if you want very verbose
#    output written to the Grid Engine output file by OpenMPI.
# 5. Uncomment the DISABLE_MXM if you want to prohibit the use of
#    MellanoX Messaging accelerator.  Disabling MXM implicitly
#    disabled the accelerated collectives functionality.
# 6. Uncomment the DISABLE_ACCEL_COLL if you want to prohibit the use
#    of Mellanox accelerated MPI collectives.
# 7. If you use exclusive=1, please be aware that NPROC will be
#    rounded up to a multiple of 20.  In this case, set the
#    WANT_NPROC variable to the actual core count you want.  The
#    script will "load balance" that core count across the N nodes
#    the job receives.
# 8. Jobs default to using 1 GB of system memory per slot.  If you
#    need more than that, set the m_mem_free complex.
#
#$ -pe mpi 60
#
# Change the following to #$ and set the amount of memory you need
# per-slot if you're getting out-of-memory errors using the
# default:
#$ -l m_mem_free=2800M
#
# Change the following to #$ if you want exclusive node access
# (see 7. above):
#$ -l exclusive=1
#
# If you want an email message to be sent to you when your job ultimately
# finishes, edit the -M line to have your email address and change the
# next two lines to start with #$ instead of just #
# -m eas
# -M my_address@mail.server.com
#

#
# Setup the PYXAID virtualenv:
#
vpkg_require pyxaid/20201110

#
# Which Python command should be used to run the script -- defaults
# to "python" but you may need to set to "python3" depending on your
# virtualenv:
#
PYXAID_INTERPRETER="python"

#
# The MPI program to execute:
#
PYXAID_SCRIPT="para-pyxaid.py"

#
# Arguments to the script program being executed.  Remember to use quotes
# around any arguments with whitespace or special characters, e.g.
#
#   MY_EXE_ARGS=("this is arg1" arg2 arg3)
PYXAID_SCRIPT_ARGS=()

#
# By default the slot count granted by Grid Engine will be
# used, one MPI worker per slot.  Set this variable if you
# want to use fewer cores than Grid Engine granted you (e.g.
# when using exclusive=1):
#
#WANT_NPROC=0

#
# Ask Open MPI to do processor binding?
#
#WANT_CPU_AFFINITY=YES

#
# Uncomment to enable lots of additional information as OpenMPI executes
# your job:
#
#SHOW_MPI_DEBUGGING=YES

#
# Normally we'll allow MXM usage, but the user can disable it by
# uncommenting the next line:
#
#DISABLE_MXM=YES

#
# Normally we'll allow Mellanox HCOLL accelerated collectives, but the user
# can disable it by uncommenting the next line:
#
#DISABLE_ACCEL_COLL=YES

##
## You should NOT need to change anything after this comment.
##
OPENMPI_VERSION='unknown'
OMPI_INFO="$(which ompi_info)"
if [ $? -eq 0 -a -n "$OMPI_INFO" ]; then
  OPENMPI_VERSION="$(${OMPI_INFO} --version | egrep 'v[0-9]+' | sed 's/^.*v//')"
  OPENMPI_VERSION_MAJOR="$(echo $OPENMPI_VERSION | sed 's/\..*$//')"
fi
#
if [ "$OPENMPI_VERSION_MAJOR" -lt 3 ]; then
  OPENMPI_FLAGS="--display-map --mca btl sm,openib,self"
else
  OPENMPI_FLAGS="--display-map --mca btl vader,openib,self"
fi
#
if [ "${DISABLE_MXM:-NO}" = "YES" ]; then
  OPENMPI_FLAGS="${OPENMPI_FLAGS} -mca mtl ^mxm"
else
  # MXM doesn't like unlimited stack sizes:
  ulimit -s 10240
  # Farber nodes have a single IB port, period:
  export MXM_IB_PORTS="mlx4_0:1"
  if [ "${DISABLE_ACCEL_COLL:-NO}" = "YES" ]; then
    OPENMPI_FLAGS="${OPENMPI_FLAGS} -mca coll ^hcoll"
  else
    OPENMPI_FLAGS="${OPENMPI_FLAGS} -mca coll self,basic,hcoll,tuned,libnbc"
    # Farber nodes have a single IB port, period:
    export HCOLL_IB_IF_INCLUDE="mlx4_0:1"
    export HCOLL_BCOL="basesmuma,mlnx_p2p"
    export HCOLL_SBGP="basesmuma,p2p"
  fi
fi
#
if [ "${WANT_CPU_AFFINITY:-NO}" = "YES" ]; then
  OPENMPI_FLAGS="${OPENMPI_FLAGS} --bind-to core"
fi
#
if [ "${WANT_NPROC:-0}" -gt 0 ]; then
  OPENMPI_FLAGS="${OPENMPI_FLAGS} --np ${WANT_NPROC} --map-by node"
fi
#
if [ "${SHOW_MPI_DEBUGGING:-NO}" = "YES" ]; then
  OPENMPI_FLAGS="${OPENMPI_FLAGS} --debug-devel --debug-daemons --display-devel-map --display-devel-allocation --mca mca_verbose 1 --mca coll_base_verbose 1 --mca ras_base_verbose 1 --mca ras_gridengine_debug 1 --mca ras_gridengine_verbose 1 --mca btl_base_verbose 1 --mca mtl_base_verbose 1 --mca plm_base_verbose 1 --mca pls_rsh_debug 1"
  if [ "${WANT_CPU_AFFINITY:-NO}" = "YES" ]; then
    OPENMPI_FLAGS="${OPENMPI_FLAGS} --report-bindings"
  fi
  if [ "${DISABLE_MXM:-NO}" != "YES" ]; then
    OPENMPI_FLAGS="${OPENMPI_FLAGS} --mca mtl_mxm_verbose 80"
    if [ "${DISABLE_ACCEL_COLL:-NO}" != "YES" ]; then
      OPENMPI_FLAGS="${OPENMPI_FLAGS} --mca coll_hcoll_verbose 80"
    fi
  fi
fi

echo "GridEngine parameters:"
echo "  mpirun        = "`which mpirun`
echo "  nhosts        = $NHOSTS"
echo "  nproc         = $NSLOTS"
echo "  Open MPI vers = $OPENMPI_VERSION"
echo "  MPI flags     = $OPENMPI_FLAGS"
echo "  interpreter   = $PYXAID_INTERPRETER"
echo "  script        = $PYXAID_SCRIPT"
echo "    arguments   = ${PYXAID_SCRIPT_ARGS[@]}"
echo "-- begin PYXAID run --"
mpirun ${OPENMPI_FLAGS} "$PYXAID_INTERPRETER" "$PYXAID_SCRIPT" "${PYXAID_SCRIPT_ARGS[@]}"
rc=$?
echo "-- end PYXAID run --"

exit $rc
