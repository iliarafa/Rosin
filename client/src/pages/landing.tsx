import { useLocation } from "wouter";

export default function Landing() {
  const [, navigate] = useLocation();

  return (
    <div
      className="min-h-screen flex items-center justify-center bg-black cursor-pointer"
      onClick={() => navigate("/terminal")}
    >
      <img
        src="/rosin-logo.png"
        alt="Rosin"
        className="w-64 h-64 hover:opacity-80 transition-opacity duration-200"
        draggable={false}
      />
    </div>
  );
}
