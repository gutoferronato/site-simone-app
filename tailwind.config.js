const config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
    "./lib/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        wine: "#5b0710",
        wineDark: "#2d0408",
        gold: "#f3c15d",
        rose: "#b77c87",
        beige: "#f6ede6",
      },
      fontFamily: {
        sans: ["var(--font-inter)", "Arial", "Helvetica", "sans-serif"],
        serif: ["var(--font-serif)", "Georgia", "serif"],
      },
      boxShadow: {
        soft: "0 10px 40px rgba(0,0,0,0.4)",
        goldGlow: "0 0 40px rgba(243,193,93,0.25)",
      },
      borderRadius: {
        xl2: "28px",
        xl3: "32px",
      },
    },
  },
  plugins: [],
};

export default config;