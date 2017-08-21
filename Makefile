example:
	dub run --config=example

library:
	dub build
	
library-ldc:
	dub build --compiler=ldc2
		
test: test-dmd test-ldc
test-dmd:
	dub test
test-ldc:
	dub test --compiler=ldc2