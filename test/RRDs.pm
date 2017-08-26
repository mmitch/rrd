# mocked RRDs module because it is not so easy to
# install the real module in a Travis CI environment
# without installing and building the whole rrdtools
# package...
#
# we only want to syntax-check our perl files, so a
# mock implementation is completely fine

package RRDs;

use Exporter 'import';

$error = 0;

@EXPORT = qw(error);

1;
