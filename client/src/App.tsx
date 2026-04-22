import { Switch, Route } from "wouter";
import { queryClient } from "./lib/queryClient";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import Novice from "@/pages/novice";
import Terminal from "@/pages/terminal";
import Welcome from "@/pages/welcome";
import ReadmePage from "@/pages/readme";
import RecommendationsPage from "@/pages/recommendations";
import HeatmapPage from "@/pages/heatmap";
import SignInPage from "@/pages/sign-in";
import NotFound from "@/pages/not-found";

function Router() {
  return (
    <Switch>
      <Route path="/" component={Novice} />
      <Route path="/pro" component={Terminal} />
      {/* Backward-compat: existing /terminal URLs still land in Terminal */}
      <Route path="/terminal" component={Terminal} />
      <Route path="/welcome" component={Welcome} />
      <Route path="/readme" component={ReadmePage} />
      <Route path="/recommendations" component={RecommendationsPage} />
      {/* History/report drawer routes — keep pointing at Terminal */}
      <Route path="/history" component={Terminal} />
      <Route path="/report/:id" component={Terminal} />
      <Route path="/heatmap" component={HeatmapPage} />
      <Route path="/sign-in" component={SignInPage} />
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
