import { Match } from "../models/Match";

export const runCompatibilityMigrations = async (): Promise<void> => {
  await Match.updateMany({ status: "completed" }, { $set: { status: "confirmed" } });
  await Match.updateMany({ status: { $in: ["scheduled", "in_progress"] } }, { $set: { status: "pending" } });
  await Match.db.collection("players").updateMany(
    { birthDate: { $exists: false }, birthYear: { $exists: true } },
    [{ $set: { birthDate: { $dateFromString: { dateString: { $concat: [{ $toString: "$birthYear" }, "-01-01"] } } } } }]
  );
};
