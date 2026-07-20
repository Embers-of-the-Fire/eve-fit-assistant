export type VariantInfo = {
    identifier: string;
    content_hash: string;
    size: number;
    download_url: string;
};

export type ArtifactInfo = {
    id: string;
    version: string;
    android: Record<string, VariantInfo> | null;
};

export type PageState = "loading" | "loaded" | "error" | "empty";

let _state = $state<PageState>("loading");
let _channels = $state<string[]>([]);
let _artifacts = $state<Record<string, ArtifactInfo>>({});
let _activeChannel = $state("testing");

export const downloadState = {
    get state() {
        return _state;
    },
    set state(val: PageState) {
        _state = val;
    },
    get channels() {
        return _channels;
    },
    set channels(val: string[]) {
        _channels = val;
    },
    get artifacts() {
        return _artifacts;
    },
    set artifacts(val: Record<string, ArtifactInfo>) {
        _artifacts = val;
    },
    get activeChannel() {
        return _activeChannel;
    },
    set activeChannel(val: string) {
        _activeChannel = val;
    },
};
