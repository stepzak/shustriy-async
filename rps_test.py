# rps_test.py
import socket
import time
import threading


def client_task(host, port, num_requests, results):
    """Выполняет num_requests запросов и записывает время успешных."""
    for _ in range(num_requests):
        start = time.perf_counter()
        try:
            sock = socket.socket()
            sock.connect((host, port))
            sock.send(b"ping\n")
            sock.recv(1024)
            sock.close()
            end = time.perf_counter()
            results.append(end - start)  # Только успешные запросы
        except Exception as e:
            # Игнорируем ошибку, но не прерываем поток
            pass  # Можно логировать: print(f"Ошибка: {e}")


def measure_rps(host='localhost', port=8080, total_requests=1000, concurrency=10):
    """Замеряет RPS по успешным запросам."""
    requests_per_client = total_requests // concurrency
    threads = []
    results = []  # Список времени успешных запросов

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
    successful_requests = len(results)

    if successful_requests == 0:
        print("Ни один запрос не удался!")
        return

    rps = successful_requests / total_time
    avg_latency = sum(results) / successful_requests

    print(f"Всего попыток: {total_requests}")
    print(f"Успешных запросов: {successful_requests}")
    print(f"Параллельность: {concurrency}")
    print(f"Общее время: {total_time:.2f} сек")
    print(f"RPS (успешные): {rps:.2f}")
    print(f"Средняя задержка: {avg_latency * 1000:.2f} мс")
    print(f"Процент успеха: {successful_requests / total_requests * 100:.1f}%")


if __name__ == "__main__":
    measure_rps(total_requests=5000, concurrency=20)