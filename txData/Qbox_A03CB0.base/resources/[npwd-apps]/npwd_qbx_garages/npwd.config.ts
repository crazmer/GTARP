import App from './src/App';
import { GarageIcon, NotificationIcon } from './icon';

export const path = '/npwd_qbx_garages';
export default () => ({
  id: 'npwd_qbx_garages',
  nameLocale: 'Garage',
  color: '#fff',
  backgroundColor: '#333',
  path,
  icon: GarageIcon,
  app: App,
  notificationIcon: NotificationIcon
});