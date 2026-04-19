"""
Selectel Golden IP Hunter v3 — Parallel Edition (Safe Delete)
Параллельный перебор во всех регионах одновременно.
Гарантированное удаление ненужных IP.
"""
 
import subprocess
import json
import sys
import time
import os
import argparse
import threading
from datetime import datetime
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
 
TARGET_SUBNETS = {
    "185.91.54","188.68.218","185.91.53","37.9.4","5.178.85",
    "185.91.52","81.163.22","81.163.23","87.228.101","5.188.114",
    "31.184.215","82.202.249","82.202.197","5.188.115","82.202.206",
    "82.202.247","5.188.113","82.202.244","82.202.252","82.202.231",
    "82.202.207","82.202.218","82.202.230","82.202.225","82.202.233",
    "109.71.12","185.91.55","188.68.219","5.188.112","109.71.13",
    "82.202.195","82.202.199","82.202.224","82.202.228","82.202.251",
    "82.202.220","82.202.254","82.202.198","82.202.237","82.202.248",
    "82.202.238","82.202.243","82.202.202","82.202.216","82.202.219",
    "82.202.223","82.202.205","82.202.211","82.202.240","82.202.253",
    "82.202.213","82.202.209","82.202.255","82.202.239","82.202.222",
    "82.202.194","82.202.192","82.202.208","82.202.210","82.202.212",
    "82.202.214","82.202.236","82.202.245","82.202.250","82.202.193",
    "82.202.217","82.202.234","82.202.196","82.202.201","82.202.227",
    "82.202.246","82.202.204","82.202.226","82.202.235","82.202.200",
    "82.202.221","82.202.242","46.148.227","82.202.215","82.202.241",
    "92.53.68","46.148.234","80.93.181","92.53.77","94.26.224",
    "212.92.101","31.41.157","46.21.248","82.202.203","92.53.91",
    "188.68.203","188.68.221","212.41.17","31.184.211","31.184.254",
    "37.9.13","45.131.40","45.92.176","45.92.177","46.148.235",
    "5.101.51","77.223.114","78.155.192","80.249.147","80.93.187",
    "84.38.182","87.242.108","91.206.14","94.26.248","95.213.167",
    "95.213.232","185.143.174","185.151.243","188.124.37","188.124.39",
    "188.68.222","212.92.98","31.172.128","31.184.218","31.184.253",
    "46.182.24","5.101.50","5.188.118","5.188.119","5.188.158",
    "5.188.159","5.188.56","5.189.239","77.244.215","77.244.217",
    "80.249.145","80.249.146","80.93.182","84.38.181","84.38.185",
    "89.248.192","89.248.193","92.53.64","92.53.66","92.53.78",
    "92.53.90","94.26.228","94.26.246","95.213.158","95.213.172",
    "95.213.195","95.213.204","95.213.211","95.213.236",
    "5.188.198","31.129.42","31.129.52","31.131.251","45.90.244",
    "5.35.8","45.130.11","77.223.110","82.148.14","92.53.74",
    "92.118.86","164.138.102","80.249.129","188.124.38","188.124.46",
    "81.163.20","95.213.246","95.213.176","5.188.80","31.129.42",
}
 
 
# ─── Потокобезопасное состояние ───────────────────────────────────────
class SharedState:
    def __init__(self, keep_count, max_attempts):
        self.lock = threading.Lock()
        self.print_lock = threading.Lock()
        self.found = []
        self.stats = Counter()
        self.attempt = 0
        self.keep_count = keep_count
        self.max_attempts = max_attempts
        self.stop_event = threading.Event()
        self.start_time = datetime.now()
        self.dead_regions = set()
 
        # Трекинг всех созданных IP для гарантированной очистки
        self.pending_delete = {}       # {fip_id: {"ip": ..., "region": ..., "created": ...}}
        self.failed_deletes = []       # IP которые не удалось удалить
        self.delete_count = 0          # Успешно удалённых
        self.golden_ids = set()        # ID золотых — не удалять
 
    def next_attempt(self):
        with self.lock:
            self.attempt += 1
            num = self.attempt
        return num
 
    def should_stop(self):
        if self.stop_event.is_set():
            return True
        with self.lock:
            if len(self.found) >= self.keep_count:
                return True
            if 0 < self.max_attempts < self.attempt:
                return True
        return False
 
    def add_found(self, result):
        with self.lock:
            self.found.append(result)
            self.golden_ids.add(result["fip_id"])
            count = len(self.found)
            done = count >= self.keep_count
        return count, done
 
    def add_stat(self, subnet_prefix):
        with self.lock:
            self.stats[subnet_prefix] += 1
 
    def mark_dead(self, region):
        with self.lock:
            self.dead_regions.add(region)
 
    def is_dead(self, region):
        with self.lock:
            return region in self.dead_regions
 
    def track_created(self, fip_id, ip, region):
        """Регистрируем созданный FIP для отслеживания."""
        with self.lock:
            self.pending_delete[fip_id] = {
                "ip": ip,
                "region": region,
                "created": datetime.now().isoformat(),
            }
 
    def track_deleted(self, fip_id):
        """Помечаем FIP как успешно удалённый."""
        with self.lock:
            self.pending_delete.pop(fip_id, None)
            self.delete_count += 1
 
    def track_failed_delete(self, fip_id, ip, region, error):
        """Помечаем FIP как неудалённый."""
        with self.lock:
            self.pending_delete.pop(fip_id, None)
            self.failed_deletes.append({
                "fip_id": fip_id,
                "ip": ip,
                "region": region,
                "error": str(error),
                "time": datetime.now().isoformat(),
            })
 
    def get_orphans(self):
        """Получить список FIP которые создали но не удалили (и не золотые)."""
        with self.lock:
            orphans = []
            for fip_id, info in self.pending_delete.items():
                if fip_id not in self.golden_ids:
                    orphans.append((fip_id, info["ip"], info["region"]))
            return orphans
 
    def safe_print(self, *args, **kwargs):
        with self.print_lock:
            print(*args, **kwargs, flush=True)
 
 
# ─── OpenStack операции ───────────────────────────────────────────────
def create_fip(region):
    cmd = [
        "openstack", "floating", "ip", "create", "external-network",
        "--os-region-name", region,
        "-f", "value",
        "-c", "floating_ip_address",
        "-c", "id",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    lines = result.stdout.strip().split("\n")
    if len(lines) >= 2:
        return lines[0].strip(), lines[1].strip()
    raise RuntimeError(f"Unexpected output: {result.stdout}")
 
 
def delete_fip_reliable(fip_id, region, state, ip="?", max_retries=3):
    """
    Надёжное удаление FIP с ретраями и верификацией.
    Возвращает True если удалено, False если не удалось.
    """
    for attempt in range(1, max_retries + 1):
        try:
            cmd = [
                "openstack", "floating", "ip", "delete", fip_id,
                "--os-region-name", region,
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
 
            if result.returncode == 0:
                # Верификация: проверяем что IP реально удалён
                verify_cmd = [
                    "openstack", "floating", "ip", "show", fip_id,
                    "--os-region-name", region,
                    "-f", "value", "-c", "id",
                ]
                verify = subprocess.run(
                    verify_cmd, capture_output=True, text=True, timeout=30
                )
 
                if verify.returncode != 0:
                    # Не найден = успешно удалён
                    state.track_deleted(fip_id)
                    return True
                else:
                    # Ещё существует, пробуем снова
                    if attempt < max_retries:
                        state.safe_print(
                            f"    ⚠ {ip} ({region}) — удаление не подтверждено, "
                            f"повтор {attempt}/{max_retries}..."
                        )
                        time.sleep(2 * attempt)
                    continue
 
            else:
                stderr = result.stderr.strip().lower()
                # Если "not found" — уже удалён, ок
                if "not found" in stderr or "no floating" in stderr or "404" in stderr:
                    state.track_deleted(fip_id)
                    return True
 
                if attempt < max_retries:
                    state.safe_print(
                        f"    ⚠ {ip} ({region}) — ошибка удаления: "
                        f"{result.stderr.strip()[:60]}, повтор {attempt}/{max_retries}..."
                    )
                    time.sleep(2 * attempt)
 
        except subprocess.TimeoutExpired:
            if attempt < max_retries:
                state.safe_print(
                    f"    ⚠ {ip} ({region}) — таймаут удаления, "
                    f"повтор {attempt}/{max_retries}..."
                )
                time.sleep(2 * attempt)
 
        except Exception as e:
            if attempt < max_retries:
                state.safe_print(
                    f"    ⚠ {ip} ({region}) — {e}, повтор {attempt}/{max_retries}..."
                )
                time.sleep(2 * attempt)
 
    # Все попытки исчерпаны
    state.safe_print(f"    ✗✗ FAILED DELETE: {ip} (ID: {fip_id}, region: {region})")
    state.track_failed_delete(fip_id, ip, region, "all retries exhausted")
    return False
 
 
def prefix(ip):
    return ".".join(ip.split(".")[:3])
 
 
def is_golden(ip, target_specific=None):
    p = prefix(ip)
    if target_specific:
        return p == target_specific
    return p in TARGET_SUBNETS
 
 
# ─── Очистка сирот ───────────────────────────────────────────────────
def cleanup_orphans(state):
    """Удалить все FIP которые создали но не удалили (кроме золотых)."""
    orphans = state.get_orphans()
    if not orphans:
        return
 
    state.safe_print(f"\n  🧹 Очистка {len(orphans)} незавершённых FIP...")
 
    for fip_id, ip, region in orphans:
        state.safe_print(f"    Удаляю {ip} ({region})...")
        delete_fip_reliable(fip_id, region, state, ip, max_retries=5)
 
    # Проверяем ещё раз
    remaining = state.get_orphans()
    if remaining:
        state.safe_print(f"  ⚠ Осталось {len(remaining)} неудалённых FIP!")
        for fip_id, ip, region in remaining:
            state.safe_print(f"    ✗ {ip} (ID: {fip_id}, region: {region})")
            state.track_failed_delete(fip_id, ip, region, "orphan cleanup failed")
 
 
# ─── Воркер для одного региона ────────────────────────────────────────
def region_worker(region, state, delay, target_subnet, workers_per_region):
    """
    Бесконечный цикл создания/проверки FIP в одном регионе.
    """
    consecutive_errors = 0
 
    while not state.should_stop():
        attempt_num = state.next_attempt()
 
        if state.is_dead(region):
            return
 
        try:
            ip, fip_id = create_fip(region)
 
            # Сразу трекаем — если что-то упадёт дальше, cleanup подберёт
            state.track_created(fip_id, ip, region)
 
            consecutive_errors = 0
            p = prefix(ip)
            state.add_stat(p)
 
            if is_golden(ip, target_subnet):
                elapsed = datetime.now() - state.start_time
                result = {
                    "ip": ip,
                    "subnet": f"{p}.0/24",
                    "fip_id": fip_id,
                    "region": region,
                    "attempt": attempt_num,
                    "elapsed": str(elapsed).split(".")[0],
                }
                count, done = state.add_found(result)
 
                state.safe_print()
                state.safe_print("★" * 62)
                state.safe_print(f"  ★  ЗОЛОТОЙ IP #{count} ПОЙМАН!")
                state.safe_print(f"  ★  IP       : {ip}")
                state.safe_print(f"  ★  Подсеть  : {p}.0/24")
                state.safe_print(f"  ★  Регион   : {region}")
                state.safe_print(f"  ★  FIP ID   : {fip_id}")
                state.safe_print(f"  ★  Попытка  : #{attempt_num}")
                state.safe_print(f"  ★  Время    : {elapsed}")
                state.safe_print("★" * 62)
                state.safe_print()
 
                if done:
                    state.stop_event.set()
                    return
                continue
            else:
                # Надёжное удаление с ретраями
                delete_fip_reliable(fip_id, region, state, ip)
                elapsed = datetime.now() - state.start_time
                state.safe_print(
                    f"  [{attempt_num:>5}] {region} │ "
                    f"{ip:<18} │ {p:>15}.* │ ✗ │ "
                    f"{str(elapsed).split('.')[0]}"
                )
 
        except RuntimeError as e:
            err = str(e).lower()
            consecutive_errors += 1
 
            if "quota" in err or "limit" in err or "exceeded" in err:
                state.safe_print(f"  [{attempt_num:>5}] {region} │ ⚠ Квота — жду 10с")
                time.sleep(10)
            else:
                state.safe_print(f"  [{attempt_num:>5}] {region} │ ⚠ {str(e)[:80]}")
 
            if consecutive_errors >= 5:
                state.safe_print(f"  [!] {region} — 5 ошибок подряд, отключаю")
                state.mark_dead(region)
                return
 
        except subprocess.TimeoutExpired:
            state.safe_print(f"  [{attempt_num:>5}] {region} │ ⚠ Таймаут")
            consecutive_errors += 1
 
        except Exception as e:
            state.safe_print(f"  [{attempt_num:>5}] {region} │ ⚠ {e}")
            consecutive_errors += 1
 
        time.sleep(delay)
 
 
# ─── Главный цикл ────────────────────────────────────────────────────
def hunt(regions, delay, max_attempts, target_subnet, keep_count, workers_per_region):
    state = SharedState(keep_count, max_attempts)
 
    print("=" * 62)
    print("  🎯  SELECTEL GOLDEN IP HUNTER v3 — PARALLEL (SAFE)")
    print("=" * 62)
    print(f"  Целевых подсетей     : {len(TARGET_SUBNETS)}")
    if target_subnet:
        print(f"  Ищу конкретную       : {target_subnet}.0/24")
    print(f"  Регионы              : {', '.join(regions)}")
    print(f"  Воркеров на регион   : {workers_per_region}")
    total_workers = len(regions) * workers_per_region
    print(f"  Всего потоков        : {total_workers}")
    print(f"  Задержка (на воркер) : {delay}с")
    print(f"  Макс. попыток        : {'∞' if max_attempts == 0 else max_attempts}")
    print(f"  Ловлю IP             : {keep_count} шт.")
    print(f"  Удаление             : 3 попытки + верификация")
    print("=" * 62)
    print()
 
    # Запускаем по N воркеров на каждый регион
    with ThreadPoolExecutor(max_workers=total_workers, thread_name_prefix="hunter") as pool:
        futures = []
        for region in regions:
            for w in range(workers_per_region):
                fut = pool.submit(
                    region_worker, region, state, delay, target_subnet, workers_per_region
                )
                futures.append((region, w, fut))
 
        try:
            for region, w, fut in futures:
                try:
                    fut.result()
                except Exception as e:
                    state.safe_print(f"  [!] Воркер {region}#{w} упал: {e}")
        except KeyboardInterrupt:
            print("\n\n[*] Остановлено (Ctrl+C)")
            state.stop_event.set()
            time.sleep(2)
 
    # Очистка незавершённых FIP
    cleanup_orphans(state)
 
    # ─── Итоги ────────────────────────────────────────────────────────
    elapsed = datetime.now() - state.start_time
    print()
    print("=" * 62)
    print("  📊  ИТОГИ")
    print("=" * 62)
    print(f"  Попыток         : {state.attempt}")
    print(f"  Время           : {str(elapsed).split('.')[0]}")
    print(f"  Успешно удалено : {state.delete_count}")
    print(f"  Поймано золотых : {len(state.found)}")
 
    if state.found:
        print()
        print("  🏆 Пойманные:")
        for i, r in enumerate(state.found, 1):
            print(f"    {i}. {r['ip']}  ({r['region']})  ID: {r['fip_id']}")
 
    if state.failed_deletes:
        print()
        print(f"  ⚠⚠⚠  НЕ УДАЛОСЬ УДАЛИТЬ {len(state.failed_deletes)} IP:")
        for fd in state.failed_deletes:
            print(f"    ✗ {fd['ip']}  ID: {fd['fip_id']}  ({fd['region']})")
        print("  ^^^  УДАЛИТЕ ИХ ВРУЧНУЮ В ПАНЕЛИ!  ^^^")
 
        # Сохраняем в файл для удобства
        fail_fname = f"failed_deletes_{datetime.now():%Y%m%d_%H%M%S}.json"
        with open(fail_fname, "w") as f:
            json.dump(state.failed_deletes, f, indent=2)
        print(f"  💾 Список неудалённых: {fail_fname}")
 
    if state.stats:
        print()
        print("  Топ-10 подсетей:")
        for p, count in state.stats.most_common(10):
            m = " ★ GOLDEN" if p in TARGET_SUBNETS else ""
            print(f"    {p:>15}.* : {count:>4}{m}")
 
    if state.dead_regions:
        print()
        print(f"  💀 Мёртвые регионы: {', '.join(state.dead_regions)}")
 
    print("=" * 62)
 
    if state.found:
        fname = f"golden_ips_{datetime.now():%Y%m%d_%H%M%S}.json"
        with open(fname, "w") as f:
            json.dump(state.found, f, indent=2)
        print(f"  💾 {fname}")
 
 
def main():
    parser = argparse.ArgumentParser(description="Golden IP Hunter v3 — Parallel (Safe)")
    parser.add_argument("-r", "--regions", default="ru-1,ru-2,ru-3",
                        help="Регионы через запятую (default: ru-1,ru-2,ru-3)")
    parser.add_argument("-d", "--delay", type=float, default=0.5,
                        help="Задержка между попытками в каждом воркере (default: 0.5)")
    parser.add_argument("-m", "--max-attempts", type=int, default=0,
                        help="Макс. попыток суммарно, 0=∞ (default: 0)")
    parser.add_argument("-t", "--target", default=None,
                        help='Конкретная подсеть, напр. "82.202.249"')
    parser.add_argument("-c", "--count", type=int, default=1,
                        help="Сколько золотых IP ловить (default: 1)")
    parser.add_argument("-w", "--workers", type=int, default=2,
                        help="Воркеров на каждый регион (default: 2)")
    args = parser.parse_args()
 
    # Проверка CLI
    print("  Проверка openstack CLI...")
    try:
        r = subprocess.run(
            ["openstack", "token", "issue", "-f", "value", "-c", "project_id"],
            capture_output=True, text=True, timeout=30,
        )
        if r.returncode == 0:
            print(f"  ✓ Авторизован, project: {r.stdout.strip()}")
        else:
            print(f"  ✗ Ошибка авторизации: {r.stderr.strip()}")
            sys.exit(1)
    except Exception as e:
        print(f"  ✗ {e}")
        sys.exit(1)
 
    print()
    hunt(
        regions=args.regions.split(","),
        delay=args.delay,
        max_attempts=args.max_attempts,
        target_subnet=args.target,
        keep_count=args.count,
        workers_per_region=args.workers,
    )
 
 
if __name__ == "__main__":
    main()

