#!/usr/bin/env bash
set -e
set -u
set -x

# TODO
echo no linkcheck

# from the sub-script
export WORKSPACE=${WORKSPACE:-$(pwd)}
export WORKSPACE=${WORKSPACE%/}  # Remove trailing slashes
export USER=${USER:-$(whoami)}
export OMERODIR=${WORKSPACE}/OMERO.server

# VARIABLES #1
MESSAGE="Update auto-generated documentation"
PUSH_COMMAND="update-submodules develop --no-ask --push develop/latest/autogen"
OPEN_PR=false
export SPHINXOPTS=-W

# Responsibilities of caller, likely omero-docs-superbuild
test -e $WORKSPACE/OMERO.server
test -e $WORKSPACE/omero-install
test -e $WORKSPACE/omeroweb-install

if [ -e $WORKSPACE/venv ]; then
    rm -rf $WORKSPACE/venv
fi
python3 -m venv --system-site-packages $WORKSPACE/venv || virtualenv --system-site-packages $WORKSPACE/venv
$WORKSPACE/venv/bin/pip install "omero-web>=5.6.dev7"
$WORKSPACE/venv/bin/pip install future 'ansible<2.7'
$WORKSPACE/venv/bin/pip install "django-redis>=4.4,<4.9"
$WORKSPACE/venv/bin/pip install -U PyYAML==5.1
$WORKSPACE/venv/bin/pip install scc
set +u # PS1 issue
. $WORKSPACE/venv/bin/activate
set -u
export PATH=$WORKSPACE/OMERO.server/bin:$PATH:$HOME/.local/bin
export PYTHONPATH=$WORKSPACE/OMERO.server/lib/python
export OMERODIR=$WORKSPACE/OMERO.server

cd $WORKSPACE/ome-documentation/
omero/autogen_docs

# OSX compatibility for testing
MD5SUM=md5sum
type $MD5SUM || MD5SUM=md5
SHA1SUM=sha1sum
type $SHA1SUM || SHA1SUM=shasum

cd omero
run_ant(){
    ant "$@" -Dsphinx.opts="$SPHINXOPTS" -Domero.release="$OMERO_RELEASE"
}
run_ant clean html

echo "Order deny,allow
Deny from all
Allow from 134.36
Allow from 10
Satisfy Any" > _build/.htaccess
run_ant zip
for x in $WORKSPACE/ome-documentation/omero/_build/*.zip
  do
    base=`basename $x`
    dir=`dirname $x`
    pushd "$dir"
    $MD5SUM "$base" >> "$base.md5"
    $SHA1SUM "$base" >> "$base.sha1"
    popd
done