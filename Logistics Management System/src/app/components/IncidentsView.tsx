import React, { useState } from 'react';
import {
  AlertTriangle, Phone, CheckCircle, Clock, ShieldAlert,
  Search, ExternalLink, User, Truck, MapPin, Check
} from 'lucide-react';
import { IncidentItem, OrderItem } from '../types';

interface IncidentsViewProps {
  incidents: IncidentItem[];
  orders: OrderItem[];
  onResolveIncident: (incident: IncidentItem) => Promise<void>;
  onNavigateToOrder?: (orderId: string) => void;
}

export function IncidentsView({
  incidents,
  orders,
  onResolveIncident,
  onNavigateToOrder,
}: IncidentsViewProps) {
  const [filterType, setFilterType] = useState<string>('all');
  const [search, setSearch] = useState('');
  const [resolvingId, setResolvingId] = useState<string | null>(null);

  const pendingCount = incidents.filter(i => i.status !== 'resolved').length;
  const highSeverityCount = incidents.filter(i => i.severity === 'high' && i.status !== 'resolved').length;

  const filtered = incidents.filter(i => {
    const matchType = filterType === 'all' || i.type === filterType;
    const q = search.toLowerCase();
    const matchSearch =
      i.orderId.toLowerCase().includes(q) ||
      i.driverName.toLowerCase().includes(q) ||
      i.customerName.toLowerCase().includes(q) ||
      i.description.toLowerCase().includes(q);
    return matchType && matchSearch;
  });

  const handleResolve = async (incident: IncidentItem) => {
    if (!window.confirm(`Xác nhận đã giải quyết sự cố đơn hàng ${incident.orderId}?`)) return;
    setResolvingId(incident.docId);
    try {
      await onResolveIncident(incident);
    } finally {
      setResolvingId(null);
    }
  };

  const getBadgeType = (type: IncidentItem['type']) => {
    switch (type) {
      case 'sos':
        return { label: 'BÁO ĐỘNG SOS', bg: 'bg-red-500 text-white animate-pulse' };
      case 'accident':
        return { label: 'Va chạm / Tai nạn', bg: 'bg-red-50 text-red-600 border border-red-200' };
      case 'breakdown':
        return { label: 'Hư hỏng xe', bg: 'bg-amber-50 text-amber-700 border border-amber-200' };
      case 'damage':
        return { label: 'Hư hỏng hàng', bg: 'bg-orange-50 text-orange-700 border border-orange-200' };
      case 'dispute':
        return { label: 'Khiếu nại cước', bg: 'bg-blue-50 text-blue-700 border border-blue-200' };
      default:
        return { label: 'Sự cố chung', bg: 'bg-slate-100 text-slate-700' };
    }
  };

  return (
    <div className="space-y-5">
      {/* Top Warning Banner if High Severity */}
      {highSeverityCount > 0 && (
        <div className="bg-red-500 text-white rounded-2xl p-4 shadow-lg flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
              <ShieldAlert className="w-6 h-6 text-white animate-bounce" />
            </div>
            <div>
              <h3 className="font-bold text-base leading-tight">
                CẢNH BÁO: CÓ {highSeverityCount} SỰ CỐ MỨC ĐỘ CAO CẦN CAN THIỆP NGAY!
              </h3>
              <p className="text-red-100 text-xs mt-0.5">
                Bao gồm tín hiệu SOS và tai nạn giao thông từ tài xế/khách hàng trong chuyến đi.
              </p>
            </div>
          </div>
          <button
            onClick={() => setFilterType('sos')}
            className="px-4 py-2 bg-white text-red-600 rounded-xl text-xs font-bold hover:bg-red-50 shrink-0"
          >
            Lọc sự cố khẩn cấp →
          </button>
        </div>
      )}

      {/* KPI Header */}
      <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-slate-800 font-bold text-lg flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-amber-500" />
            Trung tâm Xử lý Sự cố & An toàn Chuyến đi (Incident & Safety Hub)
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Giám sát thời gian thực mọi tín hiệu SOS khẩn cấp, tai nạn giao thông, hỏng xe và khiếu nại bồi thường
          </p>
        </div>

        <div className="flex items-center gap-3 text-xs">
          <div className="px-3.5 py-1.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 font-semibold">
            {pendingCount} sự cố chưa đóng
          </div>
          <div className="px-3.5 py-1.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 font-semibold">
            {incidents.filter(i => i.status === 'resolved').length} đã xử lý
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-1.5">
          {[
            { key: 'all', label: `Tất cả (${incidents.length})` },
            { key: 'sos', label: 'Báo động SOS' },
            { key: 'accident', label: 'Tai nạn' },
            { key: 'breakdown', label: 'Hỏng xe' },
            { key: 'damage', label: 'Hư hỏng hàng' },
            { key: 'dispute', label: 'Khiếu nại cước' },
          ].map(f => (
            <button
              key={f.key}
              onClick={() => setFilterType(f.key)}
              className={`px-3.5 py-2 rounded-xl text-xs font-semibold transition-all ${
                filterType === f.key
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>

        <div className="relative flex-1 min-w-56 max-w-sm">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Tìm theo mã đơn, tài xế, khách hàng..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500"
          />
        </div>
      </div>

      {/* Incidents List */}
      <div className="space-y-3">
        {filtered.length === 0 ? (
          <div className="bg-white rounded-2xl p-12 text-center text-slate-400 border border-slate-100">
            <CheckCircle className="w-10 h-10 text-emerald-400 mx-auto mb-2" />
            <p className="text-base font-semibold text-slate-700">Không có sự cố nào cần xử lý</p>
            <p className="text-xs text-slate-400 mt-1">Toàn bộ các chuyến xe hiện tại đang vận hành an toàn và thông suốt.</p>
          </div>
        ) : (
          filtered.map(inc => {
            const b = getBadgeType(inc.type);
            const isResolved = inc.status === 'resolved';

            return (
              <div
                key={inc.docId || inc.id}
                className={`bg-white rounded-2xl p-5 border transition-all ${
                  isResolved
                    ? 'border-slate-100 opacity-70 bg-slate-50/50'
                    : inc.severity === 'high'
                    ? 'border-red-200 shadow-md ring-1 ring-red-100'
                    : 'border-slate-200 shadow-sm'
                }`}
              >
                <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                  <div className="space-y-2 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className={`px-2.5 py-1 rounded-lg text-xs font-bold ${b.bg}`}>
                        {b.label}
                      </span>
                      <span className="font-mono font-bold text-blue-600 text-sm">
                        Đơn: {inc.orderId}
                      </span>
                      <span className="text-xs text-slate-400">· {inc.time}</span>
                      {isResolved ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-700">
                          ĐÃ GIẢI QUYẾT
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800">
                          ĐANG XỬ LÝ
                        </span>
                      )}
                    </div>

                    <p className="text-slate-800 text-sm font-medium">{inc.description}</p>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 pt-1 text-xs text-slate-600">
                      <div className="flex items-center gap-1.5">
                        <Truck className="w-3.5 h-3.5 text-slate-400" />
                        <span>Tài xế: <strong>{inc.driverName}</strong></span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <User className="w-3.5 h-3.5 text-slate-400" />
                        <span>Khách hàng: <strong>{inc.customerName}</strong></span>
                      </div>
                      {inc.location && (
                        <div className="flex items-center gap-1.5">
                          <MapPin className="w-3.5 h-3.5 text-slate-400" />
                          <span className="truncate">Vị trí: {inc.location}</span>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    {!isResolved && (
                      <button
                        disabled={resolvingId === inc.docId}
                        onClick={() => handleResolve(inc)}
                        className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-emerald-600 text-white hover:bg-emerald-700 shadow-sm transition-all"
                      >
                        <Check className="w-3.5 h-3.5" /> Đánh dấu đã giải quyết
                      </button>
                    )}

                    {onNavigateToOrder && (
                      <button
                        onClick={() => onNavigateToOrder(inc.orderId)}
                        className="p-2 rounded-xl bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors"
                        title="Xem chi tiết đơn hàng"
                      >
                        <ExternalLink className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
