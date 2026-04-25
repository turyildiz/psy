import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        manrope: ["var(--font-manrope)", "Manrope", "sans-serif"],
        bricolage: ["var(--font-bricolage)", "'Bricolage Grotesque'", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
