example:
	dub run --config=example
	
test: test-dmd test-ldc
	
	
test-dmd:
	dub test

test-ldc:
	dub test --compiler=ldc2