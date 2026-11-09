import { z } from "zod";
import { Schedule, Tag } from "../shared/contract";

export const Ref = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);

export const PutAppRequest = z.object({ tag: Tag });

export const PutBlockRequest = z.object({ schedule: Schedule, appRefs: z.array(Ref).max(100) });

export const AppsResponse = z.object({ apps: z.array(z.object({ appRef: z.string(), tag: Tag })) });
