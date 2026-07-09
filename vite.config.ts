import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5174,
    strictPort: false,
    proxy: {
      "/api": "http://127.0.0.1:4174"
    }
  },
  preview: {
    port: 5175
  }
});
