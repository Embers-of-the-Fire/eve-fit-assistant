interface Env {
    FORWARD_TO: string;
}

export default {
    async email(message: ForwardableEmailMessage, env: Env, _ctx: ExecutionContext) {
        const subject = message.headers.get("subject") ?? "";
        const prefix = "[EFA/Security]";

        if (subject.startsWith(prefix)) {
            await message.forward(env.FORWARD_TO);
        } else {
            message.setReject(`Subject must start with "${prefix}"`);
        }
    },
};
