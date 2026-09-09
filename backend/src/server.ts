import { app } from "./app";
import { connectDatabase } from "./config/db";
import { env } from "./config/env";
import { startActivityMaintenance } from "./services/activityService";
import { resumeDeletions } from "./services/deletionService";

const bootstrap = async (): Promise<void> => {
  await connectDatabase();
  await resumeDeletions();
  await startActivityMaintenance();

  app.listen(env.port, () => {
    console.log(`API listening on port ${env.port}`);
  });
};

bootstrap().catch((error) => {
  console.error("Failed to start API", error);
  process.exit(1);
});
