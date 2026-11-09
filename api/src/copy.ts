// Every line the Worker puts in front of a person (push and email). Spec §10 rules: facts, numbers, questions.

export const copy = {
  signInCode: (code: string, ttlMinutes: number) => ({
    subject: `${code} is your Toll code`,
    text: `${code}\n\nEnter this code in Toll. It expires in ${ttlMinutes} minutes.\n\nIf you didn't ask for a code, ignore this email.`,
  }),
  schoolCode: (code: string, school: string, ttlMinutes: number) => ({
    subject: `${code} is your Toll school code`,
    text: `${code}\n\nEnter this code in Toll to join ${school}. It expires in ${ttlMinutes} minutes.\n\nIf you didn't ask for a code, ignore this email.`,
  }),
  invitePage: (name: string) => ({
    title: name ? `${name} invited you to Toll` : "You're invited to Toll",
    line: "Toll blocks the apps you choose. Getting past a block costs a wait. Your friends can see what you did.",
    button: "Get Toll on the App Store",
  }),
  inviteMissing: {
    title: "No one has that code",
    line: "Ask your friend for a new link.",
    button: "Get Toll on the App Store",
  },
  // To the founders' inbox, not to users.
  report: (r: {
    reason: string;
    text: string | null;
    reporter: string;
    subject: string;
    subjectName: string;
  }) => ({
    subject: `Report: ${r.reason} · ${r.subjectName}`,
    text: `Reason: ${r.reason}\nReported user: ${r.subjectName} (${r.subject})\nReporter: ${r.reporter}\n\n${r.text ?? "(no text)"}`,
  }),
  accountDeleted: () => ({
    subject: "Your Toll account was deleted",
    text: "Your Toll account and everything stored with it on our servers were deleted. This cannot be undone.\n\nQuestions: support@toll.alders.dev",
  }),
};
