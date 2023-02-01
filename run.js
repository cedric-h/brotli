// vim: sw=2 ts=2 expandtab smartindent
const fullproglen = 147*2;

(async () => {
  const fs = require("fs");

  function try_compress() {
    const buf_ptr = env.malloc(1 << 10);
    const buf = new Uint8Array(mem, buf_ptr, 1 << 10);
    for (let i = 0; i < buf.length; i++) buf[i] = i;

    const out_size_max = wasm.BrotliEncoderMaxCompressedSize(buf.length);
    const out_ptr = env.malloc(out_size_max);
    const out_size_ptr = env.malloc(32/8);

    const out_buf = new Uint8Array(mem, out_ptr, out_size_max);
    const out_size_buf = new Uint32Array(mem, out_size_ptr, 1);
    out_size_buf[0] = out_size_max;
    
    console.log( buf.length, {
      buf_len: buf.length,
      buf_ptr,
      ' ': ' ',
      out_size_max,
      out_size_ptr,
      out_size: out_size_buf[0],
      out_ptr
    });

    console.log("got max compressed size");
    const ret = wasm.BrotliEncoderCompress(
      11,  /* BROTLI_MAX_QUALITY      */
      24,  /* BROTLI_MAX_WINDOW_BITS  */
      0,   /* BROTLI_MODE_GENERIC     */
      buf.length,
      buf_ptr,
      out_size_ptr,
      out_ptr
    );
    console.log(`BrotliEncoderCompress returned ${ret}`);
    console.log(new Uint8Array(mem, out_ptr, out_size_max));
  }

  let wasm, mem;
  let heap_ptr;
  const env = {
    malloc(bytes) {
      if (heap_ptr == undefined) heap_ptr = wasm.__heap_base.value;
      const allocated_ptr = heap_ptr;
      heap_ptr += bytes;
      heap_ptr += heap_ptr - Math.floor(heap_ptr/4)*4;

      const mem_left = mem.byteLength - heap_ptr;
      if (mem_left < 0) {
        wasm.memory.grow(Math.ceil(-mem_left / (1 << 16)));
        mem = wasm.memory.buffer; /* reattach buffer */
      }
      return allocated_ptr;
    },
    free(ptr) {
    },
    log2: Math.log2,
    exit: () => { throw new Error(); },
  };

  const bytes = fs.readFileSync(process.argv[2]);
  const { instance } = await WebAssembly.instantiate(bytes, { env });
  wasm = instance.exports;
  mem = wasm.memory.buffer;
  console.log("successfully compiled " + process.argv[2]);

  try_compress();

})();
