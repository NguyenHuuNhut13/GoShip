import React, { useState } from 'react';
import {
  Package, Search, Download, Eye, CheckCircle, XCircle,
  Truck, X, User, Phone, MapPin, Calendar, Clock,
  UserCheck, Send, AlertCircle
} from 'lucide-react';
import { OrderItem, DriverItem, MapVehicleItem } from '../types';

interface OrdersViewProps {
  orders: OrderItem[];
  drivers: DriverItem[];
  vehicles: MapVehicleItem[];
  onUpdateOrderStatus: (order: OrderItem, newStatus: 'completed' | 'cancelled' | 'in_transit') => Promise<void>;
  onManualDispatch: (order: OrderItem, driver: DriverItem) => Promise<void>;
}

export function OrdersView({
  orders,
  drivers,
  vehicles,
  onUpdateOrderStatus,
  onManualDispatch,
}: OrdersViewProps) {
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [selectedOrder, setSelectedOrder] = useState<OrderItem | null>(null);
  const [dispatchOrder, setDispatchOrder] = useState<OrderItem | null>(null);
  const [updating, setUpdating] = useState(false);
  const [dispatchingDriverId, setDispatchingDriverId] = useState<string | null>(null);

  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const tabs = [
    { key: 'all', label: 'Tất cả', count: orders.length },
    { key: 'in_transit', label: 'Đang giao', count: orders.filter(o => o.status === 'in_transit').length },
    { key: 'pending', label: 'Chờ tài xế', count: orders.filter(o => o.status === 'pending').length },
    { key: 'completed', label: 'Hoàn thành', count: orders.filter(o => o.status === 'completed').length },
    { key: 'cancelled', label: 'Đã hủy', count: orders.filter(o => o.status === 'cancelled').length },
  ];

  const filtered = orders.filter(o => {
    const matchStatus = statusFilter === 'all' || o.status === statusFilter;
    const q = search.toLowerCase();
    const matchSearch =
      o.id.toLowerCase().includes(q) ||
      o.customer.toLowerCase().includes(q) ||
      o.customerPhone.includes(q) ||
      o.driver.toLowerCase().includes(q);
    return matchStatus && matchSearch;
  });

  const totalPages = Math.ceil(filtered.length / pageSize) || 1;
  const paginatedOrders = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const fmtVND = (amt: number) => amt.toLocaleString('vi-VN') + ' đ';

  const ORDER_STATUS_CONFIG: Record<string, { label: string; bg: string; text: string }> = {
    pending: { label: 'Chờ tài xế', bg: 'bg-amber-50', text: 'text-amber-700' },
    in_transit: { label: 'Đang giao', bg: 'bg-blue-50', text: 'text-blue-700' },
    completed: { label: 'Hoàn thành', bg: 'bg-emerald-50', text: 'text-emerald-700' },
    cancelled: { label: 'Đã hủy', bg: 'bg-red-50', text: 'text-red-700' },
  };

  const handleExportCSV = () => {
    const headers = ['Mã đơn', 'Khách hàng', 'SĐT Khách', 'Tài xế', 'Loại xe', 'Điểm lấy', 'Điểm giao', 'Cước phí (VNĐ)', 'Trạng thái', 'Thời gian'];
    const rows = filtered.map(o => [
      o.id,
      `"${o.customer}"`,
      o.customerPhone,
      `"${o.driver}"`,
      `"${o.vehicle}"`,
      `"${o.pickup}"`,
      `"${o.dropoff}"`,
      o.fee,
      ORDER_STATUS_CONFIG[o.status]?.label || o.status,
      `${o.time} ${o.date}`,
    ]);
    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `GoShip_BaoCaoDonHang_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Lấy danh sách tài xế hợp lệ để chỉ định
  const availableDrivers = drivers.filter(d => d.status === 'active');

  const handleConfirmDispatch = async (driver: DriverItem) => {
    if (!dispatchOrder) return;
    if (!window.confirm(`Xác nhận chỉ định chuyến ${dispatchOrder.id} cho tài xế ${driver.name}?`)) return;

    setDispatchingDriverId(driver.id);
    try {
      await onManualDispatch(dispatchOrder, driver);
      setDispatchOrder(null);
      if (selectedOrder && selectedOrder.id === dispatchOrder.id) {
        setSelectedOrder(prev => prev ? {
          ...prev,
          driver: driver.name,
          driverPhone: driver.phone,
          vehicle: driver.vehicle,
          status: 'in_transit',
        } : null);
      }
    } finally {
      setDispatchingDriverId(null);
    }
  };

  return (
    <div className="space-y-5">
      {/* Top Filter & CSV Bar */}
      <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-1.5">
            {tabs.map(t => (
              <button
                key={t.key}
                onClick={() => {
                  setStatusFilter(t.key);
                  setCurrentPage(1);
                }}
                className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all ${
                  statusFilter === t.key
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
                }`}
              >
                {t.label}
                <span
                  className={`px-1.5 py-0.5 rounded-full text-[11px] ${
                    statusFilter === t.key ? 'bg-blue-500 text-white' : 'bg-slate-200 text-slate-600'
                  }`}
                >
                  {t.count}
                </span>
              </button>
            ))}
          </div>

          <button
            onClick={handleExportCSV}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm"
          >
            <Download className="w-3.5 h-3.5" /> Xuất báo cáo CSV
          </button>
        </div>

        <div className="relative">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Tìm theo mã đơn (#GS-...), tên/SĐT khách hàng, tài xế..."
            value={search}
            onChange={e => {
              setSearch(e.target.value);
              setCurrentPage(1);
            }}
            className="w-full pl-10 pr-4 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500"
          />
        </div>
      </div>

      {/* Orders Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/70">
                <th className="text-left px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Mã đơn</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Khách hàng</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Tài xế</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Loại xe</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Lộ trình</th>
                <th className="text-right px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Cước phí</th>
                <th className="text-center px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Trạng thái</th>
                <th className="text-center px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {paginatedOrders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-5 py-12 text-center text-slate-400">
                    <Package className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                    <p className="text-sm font-medium text-slate-600">Không có đơn hàng nào trong mục này</p>
                    <p className="text-xs text-slate-400">Đơn hàng mới tạo từ App Khách hàng sẽ đồng bộ tức thì vào đây.</p>
                  </td>
                </tr>
              ) : (
                paginatedOrders.map(order => {
                  const cfg = ORDER_STATUS_CONFIG[order.status] || ORDER_STATUS_CONFIG.pending;
                  return (
                    <tr key={order.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-1.5">
                          <span className="font-semibold text-blue-600">{order.id}</span>
                          {order.isCloud && (
                            <span className="px-1.5 py-0.5 text-[10px] font-bold bg-blue-50 text-blue-600 rounded">
                              CLOUD
                            </span>
                          )}
                        </div>
                        <div className="text-xs text-slate-400 mt-0.5">{order.time} · {order.date}</div>
                      </td>

                      <td className="px-4 py-4">
                        <div className="font-medium text-slate-800">{order.customer}</div>
                        <div className="text-xs text-slate-400">{order.customerPhone}</div>
                      </td>

                      <td className="px-4 py-4">
                        {order.driver && order.driver !== 'Chưa nhận đơn' && order.driver !== 'Chưa phân công' ? (
                          <div>
                            <div className="text-slate-800 font-medium">{order.driver}</div>
                            <div className="text-xs text-slate-400">{order.driverPhone}</div>
                          </div>
                        ) : (
                          <div className="flex items-center gap-1.5">
                            <span className="text-xs text-slate-400 italic">Chưa có</span>
                            <button
                              onClick={() => setDispatchOrder(order)}
                              className="px-2 py-0.5 text-[11px] font-bold bg-blue-50 text-blue-600 hover:bg-blue-100 rounded-md"
                              title="Chỉ định tài xế ngay"
                            >
                              Chỉ định →
                            </button>
                          </div>
                        )}
                      </td>

                      <td className="px-4 py-4">
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-slate-100 text-slate-700 rounded-lg text-xs font-medium">
                          <Truck className="w-3 h-3" /> {order.vehicle}
                        </span>
                      </td>

                      <td className="px-4 py-4 max-w-xs">
                        <div className="text-xs text-slate-700 truncate">📍 {order.pickup}</div>
                        <div className="text-xs text-slate-400 truncate mt-0.5">🏁 {order.dropoff}</div>
                      </td>

                      <td className="px-4 py-4 text-right">
                        <span className="font-bold text-slate-800">{fmtVND(order.fee)}</span>
                        <div className="text-[10px] text-slate-400">{order.paymentMethod}</div>
                      </td>

                      <td className="px-4 py-4 text-center">
                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${cfg.bg} ${cfg.text}`}>
                          {cfg.label}
                        </span>
                      </td>

                      <td className="px-5 py-4 text-center">
                        <div className="inline-flex items-center gap-1.5">
                          <button
                            onClick={() => setSelectedOrder(order)}
                            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors"
                          >
                            <Eye className="w-3.5 h-3.5" /> Chi tiết
                          </button>

                          {order.status === 'pending' && (
                            <button
                              onClick={() => setDispatchOrder(order)}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-semibold bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors"
                              title="Điều phối chỉ định tài xế"
                            >
                              <UserCheck className="w-3.5 h-3.5" /> Giao xe
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {filtered.length > 0 && (
          <div className="px-5 py-3.5 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3 text-xs text-slate-500">
            <div className="flex items-center gap-2">
              <span>Hiển thị</span>
              <select
                value={pageSize}
                onChange={e => {
                  setPageSize(Number(e.target.value));
                  setCurrentPage(1);
                }}
                className="bg-slate-50 border border-slate-200 rounded-lg px-2 py-1 text-xs focus:outline-none"
              >
                <option value={10}>10</option>
                <option value={25}>25</option>
                <option value={50}>50</option>
              </select>
              <span>trên tổng {filtered.length} đơn hàng</span>
            </div>

            <div className="flex items-center gap-1">
              <button
                disabled={currentPage <= 1}
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                className="px-2.5 py-1 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
              >
                Trước
              </button>
              <span className="px-3 py-1 font-semibold text-slate-800">
                {currentPage} / {totalPages}
              </span>
              <button
                disabled={currentPage >= totalPages}
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                className="px-2.5 py-1 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
              >
                Sau
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Order Details & e-POD Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-xl w-full shadow-2xl border border-slate-100 overflow-hidden max-h-[90vh] flex flex-col">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-slate-800 text-base">{selectedOrder.id}</span>
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-50 text-blue-700">
                    {ORDER_STATUS_CONFIG[selectedOrder.status]?.label || selectedOrder.status}
                  </span>
                </div>
                <p className="text-xs text-slate-400 mt-0.5">
                  {selectedOrder.time} – {selectedOrder.date} • Hình thức: {selectedOrder.paymentMethod}
                </p>
              </div>
              <button onClick={() => setSelectedOrder(null)} className="p-2 rounded-xl hover:bg-slate-100 text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-4">
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div className="bg-slate-50 rounded-xl p-3">
                  <div className="text-xs text-slate-400">Khách hàng</div>
                  <div className="font-semibold text-slate-800 mt-0.5">{selectedOrder.customer}</div>
                  <div className="text-xs text-slate-500">{selectedOrder.customerPhone}</div>
                </div>

                <div className="bg-slate-50 rounded-xl p-3">
                  <div className="text-xs text-slate-400">Tài xế thực hiện</div>
                  <div className="font-semibold text-slate-800 mt-0.5">{selectedOrder.driver}</div>
                  <div className="text-xs text-slate-500">{selectedOrder.driverPhone}</div>
                </div>

                <div className="bg-slate-50 rounded-xl p-3">
                  <div className="text-xs text-slate-400">Phương tiện</div>
                  <div className="font-semibold text-slate-800 mt-0.5">{selectedOrder.vehicle}</div>
                </div>

                <div className="bg-blue-50 rounded-xl p-3">
                  <div className="text-xs text-blue-500">Tổng cước phí</div>
                  <div className="font-bold text-blue-700 mt-0.5">{fmtVND(selectedOrder.fee)}</div>
                </div>
              </div>

              <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-xs">
                <div>📍 <strong>Điểm lấy hàng:</strong> {selectedOrder.pickup}</div>
                <div>🏁 <strong>Điểm giao hàng:</strong> {selectedOrder.dropoff}</div>
              </div>

              {/* e-POD Section */}
              <div>
                <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
                  Ảnh xác nhận giao hàng (e-POD)
                </div>
                {selectedOrder.podImg ? (
                  <div className="rounded-xl overflow-hidden border border-slate-200 relative">
                    <img src={selectedOrder.podImg} alt="e-POD" className="w-full h-48 object-cover" />
                    <div className="absolute bottom-2 right-2 bg-emerald-600 text-white text-xs px-2.5 py-1 rounded-lg flex items-center gap-1 font-medium shadow">
                      <CheckCircle className="w-3.5 h-3.5" /> Đã xác nhận e-POD
                    </div>
                  </div>
                ) : (
                  <div className="rounded-xl border-2 border-dashed border-slate-200 h-24 flex flex-col items-center justify-center text-slate-400">
                    <Package className="w-5 h-5 mb-1 text-slate-300" />
                    <span className="text-xs">Chưa có ảnh chụp biên bản giao nhận e-POD</span>
                  </div>
                )}
              </div>

              {/* Action Buttons with GPS Release Safety */}
              <div className="pt-3 flex items-center justify-between gap-3 border-t border-slate-100">
                <span className="text-xs text-slate-400">Can thiệp điều phối:</span>
                <div className="flex items-center gap-2">
                  {selectedOrder.status === 'pending' && (
                    <button
                      onClick={() => {
                        setDispatchOrder(selectedOrder);
                        setSelectedOrder(null);
                      }}
                      className="px-3.5 py-2 rounded-xl text-xs font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-sm"
                    >
                      <UserCheck className="w-3.5 h-3.5 inline mr-1" /> Chỉ định tài xế
                    </button>
                  )}

                  {selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'completed' && (
                    <button
                      disabled={updating}
                      onClick={async () => {
                        if (!window.confirm(`Xác nhận HỦY đơn hàng ${selectedOrder.id}?`)) return;
                        setUpdating(true);
                        await onUpdateOrderStatus(selectedOrder, 'cancelled');
                        setUpdating(false);
                        setSelectedOrder(null);
                      }}
                      className="px-3.5 py-2 rounded-xl text-xs font-semibold bg-red-50 text-red-600 hover:bg-red-100 transition-colors"
                    >
                      Hủy đơn hàng
                    </button>
                  )}

                  {selectedOrder.status !== 'completed' && (
                    <button
                      disabled={updating}
                      onClick={async () => {
                        if (!window.confirm(`Xác nhận đơn ${selectedOrder.id} ĐÃ HOÀN TẤT VÀ GIẢI PHÓNG TÀI XẾ?`)) return;
                        setUpdating(true);
                        await onUpdateOrderStatus(selectedOrder, 'completed');
                        setUpdating(false);
                        setSelectedOrder(null);
                      }}
                      className="px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm"
                    >
                      Xác nhận Hoàn tất
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Manual Dispatch Modal */}
      {dispatchOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-100 overflow-hidden max-h-[85vh] flex flex-col">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50/50">
              <div>
                <h3 className="font-bold text-slate-800 text-base flex items-center gap-2">
                  <UserCheck className="w-5 h-5 text-blue-600" /> Điều phối chỉ định chuyến {dispatchOrder.id}
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Chọn 1 tài xế trực tuyến phù hợp để gán cuốc trực tiếp
                </p>
              </div>
              <button onClick={() => setDispatchOrder(null)} className="p-2 rounded-xl hover:bg-slate-200 text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-3">
              <div className="bg-blue-50/60 p-3 rounded-xl border border-blue-100 text-xs text-blue-800">
                <div>Yêu cầu xe: <strong>{dispatchOrder.vehicle}</strong></div>
                <div>Lộ trình: 📍 {dispatchOrder.pickup} ➔ 🏁 {dispatchOrder.dropoff}</div>
              </div>

              <div className="text-xs font-bold text-slate-500 uppercase tracking-wider pt-1">
                Danh sách tài xế trực tuyến ({availableDrivers.length} tài xế)
              </div>

              {availableDrivers.length === 0 ? (
                <div className="py-8 text-center text-slate-400">
                  <AlertCircle className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                  Hiện không có đối tác tài xế nào đang hoạt động.
                </div>
              ) : (
                <div className="space-y-2">
                  {availableDrivers.map(drv => {
                    const isBusy = vehicles.some(v => (v.id === drv.docId || v.id === drv.id) && v.status === 'delivering');

                    return (
                      <div
                        key={drv.id}
                        className={`p-3.5 rounded-2xl border flex items-center justify-between gap-3 transition-all ${
                          isBusy
                            ? 'border-slate-100 bg-slate-50/40 opacity-70'
                            : 'border-slate-200 hover:border-blue-400 hover:bg-blue-50/20'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <img src={drv.avatar} alt="" className="w-10 h-10 rounded-full object-cover" />
                          <div>
                            <div className="font-bold text-slate-800 text-sm flex items-center gap-1.5">
                              {drv.name}
                              {isBusy ? (
                                <span className="px-1.5 py-0.5 text-[10px] bg-orange-100 text-orange-700 rounded font-medium">
                                  Đang bận
                                </span>
                              ) : (
                                <span className="px-1.5 py-0.5 text-[10px] bg-emerald-100 text-emerald-700 rounded font-medium">
                                  Sẵn sàng
                                </span>
                              )}
                            </div>
                            <div className="text-xs text-slate-500">
                              {drv.vehicle} • Biển: {drv.plate} • ⭐ {drv.rating.toFixed(1)}
                            </div>
                            <div className="text-xs text-slate-400">{drv.phone}</div>
                          </div>
                        </div>

                        <button
                          disabled={dispatchingDriverId === drv.id}
                          onClick={() => handleConfirmDispatch(drv)}
                          className="px-3.5 py-2 rounded-xl text-xs font-bold bg-blue-600 text-white hover:bg-blue-700 shadow-sm shrink-0 transition-all disabled:opacity-50"
                        >
                          {dispatchingDriverId === drv.id ? 'Đang gán...' : 'Giao chuyến'}
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
