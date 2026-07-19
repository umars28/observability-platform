// k6 load script — exercises demo-shop-api.
// Runs continuously in-cluster; sends a mixed workload:
//   70% GET /products      (cheap list)
//   20% GET /products/:id  (fans out to blog service)
//   10% POST /orders       (writes; some fail)
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.SHOP_URL || 'http://demo-shop-api.demo.svc:8080';
const PRODUCT_IDS = ['p-1', 'p-2', 'p-3', 'p-4', 'p-5', 'p-missing'];

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: 20,           // 20 requests per second
      timeUnit: '1s',
      duration: '365d',   // never ends; k8s manages lifecycle
      preAllocatedVUs: 5,
      maxVUs: 20,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.20'],
  },
};

export default function () {
  const roll = Math.random();
  const pid = PRODUCT_IDS[Math.floor(Math.random() * PRODUCT_IDS.length)];

  if (roll < 0.70) {
    const r = http.get(`${BASE}/products`);
    check(r, { 'list 200': (r) => r.status === 200 });
  } else if (roll < 0.90) {
    const r = http.get(`${BASE}/products/${pid}`);
    check(r, { 'get 200 or 404': (r) => r.status === 200 || r.status === 404 });
  } else {
    const r = http.post(
      `${BASE}/orders`,
      JSON.stringify({ product_id: pid, quantity: 1 }),
      { headers: { 'Content-Type': 'application/json' } },
    );
    check(r, { 'order 201/404/500': (r) => [201, 404, 500].includes(r.status) });
  }

  sleep(0.05);
}
