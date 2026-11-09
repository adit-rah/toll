// Every line the Worker puts in front of a person (push and email). Spec §10 rules: facts, numbers, questions.

export const copy = {
  signInCode: (code: string, ttlMinutes: number) => ({
    subject: `${code} is your Toll code`,
    text: `${code}\n\nEnter this code in Toll. It expires in ${ttlMinutes} minutes.\n\nIf you didn't ask for a code, ignore this email.`,
  }),
  accountDeleted: () => ({
    subject: "Your Toll account was deleted",
    text: "Your Toll account and everything stored with it on our servers were deleted. This cannot be undone.\n\nQuestions: support@toll.alders.dev",
  }),
};
