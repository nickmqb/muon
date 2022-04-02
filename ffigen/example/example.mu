main() {
	fp := fopen("test.txt", "w")
	assert(fp != null)
	fprintf(fp, "Hello, ffigen!\n")
	fclose(fp)
	
	printf("test.txt has been written to disk\n")
}
