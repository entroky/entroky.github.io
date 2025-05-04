export namespace Base91 {
    export function load() {
        return import("./base91.ts").then(mod => mod.Base91.load());
    }
}
export namespace DuckDB {
    export function load() {
        return import("./duckdb.js").then(mod => mod.DuckDB.load());
    }
}
export namespace Expat {
    export function load() {
        return import("./expat.ts").then(mod => mod.Expat.load());
    }
}
export namespace Graphviz {
    export function load() {
        return import("./graphviz.ts").then(mod => mod.Graphviz.load());
    }
}
export namespace Zstd {
    export function load() {
        return import("./zstd.ts").then(mod => mod.Zstd.load());
    }
}
