// dart format off
// prettier-ignore
const FIAT_CURRENCIES = new Set([
  "AED","AFN","ALL","AMD","ANG","AOA","ARS","AUD","AWG","AZN",
  "BAM","BBD","BDT","BGN","BHD","BIF","BMD","BND","BOB","BRL",
  "BSD","BTN","BWP","BYN","BZD","CAD","CDF","CHF","CLP","CNY",
  "COP","CRC","CUC","CUP","CVE","CZK","DJF","DKK","DOP","DZD",
  "EGP","ERN","ETB","EUR","FJD","FKP","GBP","GEL","GGP","GHS",
  "GIP","GMD","GNF","GTQ","GYD","HKD","HNL","HRK","HTG","HUF",
  "IDR","ILS","IMP","INR","IQD","ISK","JEP","JMD","JOD","JPY",
  "KES","KGS","KHR","KMF","KRW","KWD","KYD","KZT","LAK","LBP",
  "LKR","LRD","LSL","LYD","MAD","MDL","MGA","MKD","MMK","MNT",
  "MOP","MRU","MUR","MVR","MWK","MXN","MYR","MZN","NAD","NGN",
  "NIO","NOK","NPR","NZD","OMR","PAB","PEN","PGK","PHP","PKR",
  "PLN","PYG","QAR","RON","RSD","RUB","RWF","SAR","SBD","SCR",
  "SDG","SEK","SGD","SHP","SLL","SOS","SRD","SVC","SZL","THB",
  "TJS","TMT","TND","TOP","TRY","TTD","TWD","TZS","UAH","UGX",
  "USD","UYU","UZS","VES","VND","VUV","WST","XAF","XCD","XOF",
  "XPF","YER","ZAR","ZMW","IRR","KPW","SSP","STN","SYP","TVD",
  "VED","ZWL"
])
// dart format on

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "X-App-Key, Content-Type",
};

async function runScheduledJob(env) {
  // Build correct URL with query parameters
  const baseUrl = "https://api.unirateapi.com/api/rates";
  const params = new URLSearchParams({
    api_key: env.UNIRATE_API_KEY,
    amount: "1",
    from: "USD",
    format: "json",
  });
  const url = `${baseUrl}?${params.toString()}`;

  const response = await fetch(url, {
    headers: { "accept": "application/json" },
  });

  if (!response.ok) {
    throw new Error(
      `UniRate API error: ${response.status} ${response.statusText}`,
    );
  }

  const data = await response.json();
  const filteredRates = {};

  for (const [currency, rate] of Object.entries(data.rates)) {
    if (FIAT_CURRENCIES.has(currency)) {
      filteredRates[currency] = rate;
    }
  }

  // Keep the same structure as original API (rates key)
  data.rates = filteredRates;

  const date = new Date().toISOString().split("T")[0];

  await env.RATES_BUCKET.put(
    `rates/${date}.json`,
    JSON.stringify({
      fetchedAt: new Date().toISOString(),
      data,
    }),
    {
      httpMetadata: {
        contentType: "application/json",
      },
    },
  );

  return date;
}

export default {
  async scheduled(event, env, ctx) {
    await runScheduledJob(env);
  },

  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // POST /refresh — admin-only, no CORS needed
    if (request.method === "POST" && url.pathname === "/refresh") {
      const adminKey = request.headers.get("X-Admin-Key");
      if (!adminKey || adminKey !== env.ADMIN_ACCESS_KEY) {
        return new Response("Unauthorized", { status: 401 });
      }

      try {
        const date = await runScheduledJob(env);
        return new Response(
          JSON.stringify({ message: "Rates updated successfully", date }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      } catch (e) {
        return new Response(
          JSON.stringify({ message: "Failed to update rates", error: e.message }),
          { status: 500, headers: { "Content-Type": "application/json" } },
        );
      }
    }

    // Only GET allowed beyond this point
    if (request.method !== "GET") {
      return new Response("Unauthorized", { status: 401, headers: CORS_HEADERS });
    }

    // Validate app key
    const apiKey = request.headers.get("X-App-Key");
    if (!apiKey || apiKey.trim() === "" || apiKey.length < 10 || apiKey !== env.API_ACCESS_KEY) {
      return new Response("Unauthorized", { status: 401, headers: CORS_HEADERS });
    }

    // Serve latest rates
    if (url.pathname === "/latest") {
      const today = new Date().toISOString().split("T")[0];
      let object = await env.RATES_BUCKET.get(`rates/${today}.json`);

      if (!object) {
        // Today's rates unavailable — fall back to most recent stored file.
        // Keys are YYYY-MM-DD so lexicographic sort = chronological order.
        const list = await env.RATES_BUCKET.list({ prefix: "rates/" });
        const keys = list.objects.map((o) => o.key).sort().reverse();
        for (const key of keys) {
          object = await env.RATES_BUCKET.get(key);
          if (object) break;
        }
      }

      if (!object) {
        // No rates in R2 at all
        return new Response("Service temporarily unavailable", {
          status: 503,
          headers: CORS_HEADERS,
        });
      }

      return new Response(object.body, {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
          "X-Content-Type-Options": "nosniff",
          "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        },
      });
    }

    return new Response("Unauthorized", { status: 401, headers: CORS_HEADERS });
  },
};
