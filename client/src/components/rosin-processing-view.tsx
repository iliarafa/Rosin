import { motion } from "framer-motion";
import { type StageOutput } from "@shared/schema";

interface RosinProcessingViewProps {
  stages: StageOutput[];
  expectedStageCount: number;
}

export function RosinProcessingView({ stages, expectedStageCount }: RosinProcessingViewProps) {
  const completedStages = stages.filter((s) => s.status === "complete").length;
  const currentStage = stages.find((s) => s.status === "streaming");

  return (
    <motion.div
      className="flex flex-col items-center justify-center h-full min-h-[60vh] text-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.4 }}
    >
      {/* Pulsing green glow ring */}
      <motion.div
        className="w-20 h-20 rounded-full border-2 border-primary/40 mb-10"
        animate={{
          boxShadow: [
            "0 0 20px rgba(34, 195, 94, 0.1), 0 0 40px rgba(34, 195, 94, 0.05)",
            "0 0 30px rgba(34, 195, 94, 0.3), 0 0 60px rgba(34, 195, 94, 0.15)",
            "0 0 20px rgba(34, 195, 94, 0.1), 0 0 40px rgba(34, 195, 94, 0.05)",
          ],
          borderColor: [
            "rgba(34, 195, 94, 0.3)",
            "rgba(34, 195, 94, 0.7)",
            "rgba(34, 195, 94, 0.3)",
          ],
        }}
        transition={{ duration: 2.5, repeat: Infinity, ease: "easeInOut" }}
      >
        <motion.div
          className="w-full h-full rounded-full border border-primary/20"
          animate={{
            scale: [1, 1.08, 1],
            opacity: [0.5, 1, 0.5],
          }}
          transition={{ duration: 2.5, repeat: Infinity, ease: "easeInOut" }}
        />
      </motion.div>

      {/* PROCESSING text with neon glow */}
      <div className="space-y-3">
        <h2 className="text-sm tracking-[0.3em] font-medium neon-glow">
          PROCESSING
        </h2>

        {/* Pulsing dots */}
        <div className="flex items-center justify-center gap-1.5">
          {[0, 1, 2].map((i) => (
            <motion.span
              key={i}
              className="w-1.5 h-1.5 rounded-full bg-primary"
              animate={{ opacity: [0.2, 1, 0.2] }}
              transition={{
                duration: 1.4,
                repeat: Infinity,
                delay: i * 0.2,
                ease: "easeInOut",
              }}
            />
          ))}
        </div>
      </div>

      {/* Stage progress */}
      <motion.div
        className="mt-8 space-y-2"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.6 }}
      >
        <div className="text-xs text-muted-foreground/60 tracking-wider">
          {currentStage ? (
            <>
              STAGE {completedStages + 1} OF {expectedStageCount}
              <span className="text-primary/50 ml-2">
                {currentStage.model.provider.toUpperCase()}
              </span>
            </>
          ) : completedStages === expectedStageCount ? (
            <span className="text-primary/70">ANALYZING...</span>
          ) : (
            <>INITIALIZING...</>
          )}
        </div>

        {/* Minimal progress bar */}
        <div className="w-48 h-px bg-border mx-auto overflow-hidden">
          <motion.div
            className="h-full bg-primary/60"
            animate={{ width: `${((completedStages + (currentStage ? 0.5 : 0)) / expectedStageCount) * 100}%` }}
            transition={{ duration: 0.5, ease: "easeOut" }}
          />
        </div>
      </motion.div>
    </motion.div>
  );
}
