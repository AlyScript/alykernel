Setting up the environment:
`docker build -t riscv-env .` to create the image.
`docker run --rm -it -v $(pwd):/workspace riscv-env` to run the container.