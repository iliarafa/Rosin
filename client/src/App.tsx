import { Switch, Route } from "wouter";
import { queryClient } from "./lib/queryClient";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import Landing from "@/pages/landing";
import Terminal from "@/pages/terminal";
import ReadmePage from "@/pages/readme";
import RecommendationsPage from "@/pages/recommendations";
import HeatmapPage from "@/pages/heatmap";
import NotFound from "@/pages/not-found";

function Router() {
  return (
    <Switch>
      <Route path="/" component={Landing} />
      <Route path="/terminal" component={Terminal} />
      <Route path="/readme" component={ReadmePage} />
      <Route path="/recommendations" component={RecommendationsPage} />
      {/* History and report now live inside terminal.tsx as a slide-in drawer.
          Keep the routes pointing to Terminal for backward-compatible URLs. */}
      <Route path="/history" component={Terminal} />
      <Route path="/report/:id" component={Terminal} />
      <Route path="/heatmap" component={HeatmapPage} />
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        <Router />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
