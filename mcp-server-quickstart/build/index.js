import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ListToolsRequestSchema, CallToolRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
const NWS_API_BASE = "https://api.weather.gov";
const USER_AGENT = "weather-app/1.0";
// [1] サーバーインスタンスの初期化
const server = new Server({
    name: "weather",
    version: "1.0.0",
}, {
    capabilities: {
        tools: {},
    },
});
// Helper function for making NWS API requests
async function makeNWSRequest(url) {
    const headers = {
        "User-Agent": USER_AGENT,
        Accept: "application/geo+json",
    };
    try {
        const response = await fetch(url, { headers });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return (await response.json());
    }
    catch (error) {
        console.error("Error making NEW request:", error);
        return null;
    }
}
// [2] 利用可能なToolの一覧を返す
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            {
                name: "get_forecast",
                description: "Get weather forecast for a location",
                inputSchema: {
                    type: "object",
                    properties: {
                        latitude: {
                            type: "number",
                            description: "Latitude of the location",
                        },
                        longitude: {
                            type: "number",
                            description: "Longitude of the location",
                        },
                    },
                },
            },
        ],
    };
});
// [3] Toolの利用
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    if (request.params.name !== "get_forecast") {
        throw new Error("Unknown prompt");
    }
    const { latitude, longitude } = request.params.arguments;
    // Get grid point data
    const pointsUrl = `${NWS_API_BASE}/points/${latitude.toFixed(4)},${longitude.toFixed(4)}`;
    const pointsData = await makeNWSRequest(pointsUrl);
    if (!pointsData) {
        return {
            content: [
                {
                    type: "text",
                    text: `Failed to retrieve grid point data for coordinates: ${latitude}, ${longitude}. This location may not be supported by the NWS API (only US locations are supported).`,
                },
            ],
        };
    }
    const forecastUrl = pointsData.properties?.forecast;
    if (!forecastUrl) {
        return {
            content: [
                {
                    type: "text",
                    text: "Failed to get forecast URL from grid point data",
                },
            ],
        };
    }
    // Get forecast data
    const forecastData = await makeNWSRequest(forecastUrl);
    if (!forecastData) {
        return {
            content: [
                {
                    type: "text",
                    text: "Failed to retrieve forecast data",
                },
            ],
        };
    }
    const periods = forecastData.properties?.periods || [];
    if (periods.length === 0) {
        return {
            content: [
                {
                    type: "text",
                    text: "No forecast periods available",
                },
            ],
        };
    }
    // Format forecast periods
    const formattedForecast = periods.map((period) => [
        `${period.name || "Unknown"}:`,
        `Temperature: ${period.temperature || "Unknown"}°${period.temperatureUnit || "F"}`,
        `Wind: ${period.windSpeed || "Unknown"} ${period.windDirection || ""}`,
        `${period.shortForecast || "No forecast available"}`,
        "---",
    ].join("\n"));
    const forecastText = `Forecast for ${latitude}, ${longitude}:\n\n${formattedForecast.join("\n")}`;
    return {
        content: [
            {
                type: "text",
                text: forecastText,
            },
        ],
    };
});
const transport = new StdioServerTransport();
await server.connect(transport);
