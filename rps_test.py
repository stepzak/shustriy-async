# rps_test.py
import socket
import time
import threading

def client_task(host, port, num_requests, results):
    """Выполняет num_requests запросов и записывает время."""
    times = []
    for _ in range(num_requests):
        start = time.perf_counter()
        try:
            sock = socket.socket()
            sock.connect((host, port))
            sock.send(b"ping\n")
            sock.recv(1024)
            sock.close()
            end = time.perf_counter()
            times.append(end - start)
        except Exception as e:
            print(f"Ошибка: {e}")
            return
    results.extend(times)

def measure_rps(host='localhost', port=8080, total_requests=1000, concurrency=10):
    """Замеряет RPS с заданной параллельностью."""
    requests_per_client = total_requests // concurrency
    threads = []
    results = []

    start_time = time.perf_counter()

    for _ in range(concurrency):
        t = threading.Thread(
            target=client_task,
            args=(host, port, requests_per_client, results)
        )
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    end_time = time.perf_counter()
    total_time = end_time - start_time
    rps = total_requests / total_time

    avg_latency = sum(results) / len(results) if results else 0

    print(f"Запросов: {total_requests}")
    print(f"Параллельность: {concurrency}")
    print(f"Общее время: {total_time:.2f} сек")
    print(f"RPS: {rps:.2f}")
    print(f"Средняя задержка: {avg_latency * 1000:.2f} мс")

if __name__ == "__main__":
    measure_rps(total_requests=5000, concurrency=20)