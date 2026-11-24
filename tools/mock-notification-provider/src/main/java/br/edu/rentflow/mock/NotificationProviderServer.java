package br.edu.rentflow.mock;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

public final class NotificationProviderServer {
    private enum Mode { HEALTHY, UNAVAILABLE }

    private final AtomicReference<Mode> mode = new AtomicReference<>(Mode.HEALTHY);
    private final AtomicLong calls = new AtomicLong();
    private final ConcurrentHashMap<String, AtomicLong> received = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Boolean> delivered = new ConcurrentHashMap<>();

    public static void main(String[] args) throws Exception {
        int port = args.length == 0 ? 8090 : Integer.parseInt(args[0]);
        new NotificationProviderServer().start(port);
    }

    private void start(int port) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        server.createContext("/provider/messages", this::message);
        server.createContext("/provider/mode/healthy", exchange -> changeMode(exchange, Mode.HEALTHY));
        server.createContext("/provider/mode/unavailable", exchange -> changeMode(exchange, Mode.UNAVAILABLE));
        server.createContext("/provider/reset", this::reset);
        server.createContext("/provider/state", this::state);
        server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
        server.start();
        System.out.printf("notification-provider port=%d mode=HEALTHY%n", port);
    }

    private void message(HttpExchange exchange) throws IOException {
        if (!"POST".equals(exchange.getRequestMethod())) {
            respond(exchange, 405, "{\"error\":\"METHOD_NOT_ALLOWED\"}");
            return;
        }
        String id = exchange.getRequestHeaders().getFirst("Idempotency-Key");
        if (id == null || id.isBlank()) {
            respond(exchange, 400, "{\"error\":\"MISSING_IDEMPOTENCY_KEY\"}");
            return;
        }
        exchange.getRequestBody().readAllBytes();
        long call = calls.incrementAndGet();
        received.computeIfAbsent(id, ignored -> new AtomicLong()).incrementAndGet();
        Mode current = mode.get();
        System.out.printf("providerCall=%d notificationId=%s mode=%s%n", call, id, current);
        if (current == Mode.UNAVAILABLE) {
            respond(exchange, 503, "{\"status\":\"UNAVAILABLE\"}");
            return;
        }
        boolean duplicate = delivered.putIfAbsent(id, Boolean.TRUE) != null;
        respond(exchange, 200, "{\"status\":\"ACCEPTED\",\"duplicate\":" + duplicate + "}");
    }

    private void changeMode(HttpExchange exchange, Mode target) throws IOException {
        if (!"POST".equals(exchange.getRequestMethod())) {
            respond(exchange, 405, "{\"error\":\"METHOD_NOT_ALLOWED\"}");
            return;
        }
        mode.set(target);
        System.out.printf("providerMode=%s%n", target);
        state(exchange);
    }

    private void reset(HttpExchange exchange) throws IOException {
        if (!"POST".equals(exchange.getRequestMethod())) {
            respond(exchange, 405, "{\"error\":\"METHOD_NOT_ALLOWED\"}");
            return;
        }
        mode.set(Mode.HEALTHY);
        calls.set(0);
        received.clear();
        delivered.clear();
        System.out.println("providerReset=true");
        state(exchange);
    }

    private void state(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod()) && !"POST".equals(exchange.getRequestMethod())) {
            respond(exchange, 405, "{\"error\":\"METHOD_NOT_ALLOWED\"}");
            return;
        }
        StringBuilder counts = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, AtomicLong> item : received.entrySet()) {
            if (!first) counts.append(',');
            first = false;
            counts.append('\"').append(item.getKey()).append("\":").append(item.getValue().get());
        }
        counts.append('}');
        String body = "{\"mode\":\"" + mode.get() + "\",\"calls\":" + calls.get()
                + ",\"uniqueDelivered\":" + delivered.size() + ",\"receivedById\":" + counts + "}";
        respond(exchange, 200, body);
    }

    private static void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }
}
